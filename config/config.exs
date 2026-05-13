import Config

native_mode =
  if config_env() == :prod or
       System.get_env("GUPPY_NATIVE_RELEASE") in ["1", "true", "TRUE", "yes"] do
    :release
  else
    :debug
  end

config :guppy,
  native: Guppy.Native.Nif

config :guppy, Guppy.Native.Nif,
  crate: :guppy_nif,
  mode: native_mode
