import Config

default_nif_path =
  Path.expand("../priv/native/guppy_nif", __DIR__)

config :guppy,
  native: Guppy.Native.Nif,
  nif_path: System.get_env("GUPPY_NIF_PATH", default_nif_path)
