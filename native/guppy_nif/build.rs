use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=c_src/guppy_nif.c");
    println!("cargo:rerun-if-changed=src/lib.rs");

    let erlang_include = erlang_include_dir();

    let out_dir = PathBuf::from(std::env::var("OUT_DIR").expect("OUT_DIR missing"));

    cc::Build::new()
        .cargo_metadata(false)
        .file("c_src/guppy_nif.c")
        .include(erlang_include)
        .flag_if_supported("-Wno-unused-parameter")
        .compile("guppy_nif_c_shim");

    let archive = out_dir.join("libguppy_nif_c_shim.a");

    match std::env::var("CARGO_CFG_TARGET_OS").as_deref() {
        Ok("macos") => {
            println!("cargo:rustc-link-arg=-Wl,-force_load,{}", archive.display());
            println!("cargo:rustc-link-arg=-Wl,-undefined,dynamic_lookup");
            println!("cargo:rustc-link-arg=-Wl,-exported_symbol,_nif_init");
        }
        Ok("linux") | Ok("freebsd") => {
            println!("cargo:rustc-link-arg=-Wl,--whole-archive");
            println!("cargo:rustc-link-arg={}", archive.display());
            println!("cargo:rustc-link-arg=-Wl,--no-whole-archive");
        }
        Ok("windows") => {
            println!("cargo:rustc-link-search=native={}", out_dir.display());
            println!("cargo:rustc-link-lib=static=guppy_nif_c_shim");
        }
        _ => {
            println!("cargo:rustc-link-search=native={}", out_dir.display());
            println!("cargo:rustc-link-lib=static=guppy_nif_c_shim");
        }
    }
}

fn erlang_include_dir() -> PathBuf {
    if let Ok(path) = std::env::var("ERL_EI_INCLUDE_DIR") {
        return PathBuf::from(path);
    }

    let output = Command::new("erl")
        .args([
            "-noshell",
            "-eval",
            "io:format(\"~s\", [filename:join(code:root_dir(), \"usr/include\")]), halt().",
        ])
        .output()
        .expect("failed to execute `erl` while locating erl_nif.h; set ERL_EI_INCLUDE_DIR to override");

    if !output.status.success() {
        panic!(
            "`erl` failed while locating erl_nif.h; set ERL_EI_INCLUDE_DIR to override"
        );
    }

    let include_dir = String::from_utf8(output.stdout)
        .expect("`erl` returned non-utf8 output for include path");

    PathBuf::from(include_dir)
}
