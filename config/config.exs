import Config

# example usage:
#  Application.get_env(:hexpds, :plc_server)

config :hexpds,
  plc_server: "plc.bsky-sandbox.dev",
  appview_server: "api.bsky-sandbox.dev",
  relay_server: "bgs.bsky-sandbox.dev",
  pds_host: "pds.shreyanjain.net" # ignore pls for now
