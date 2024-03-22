import Config

# example usage:
#  Application.get_env(:hipdster, :plc_server)

config :hipdster,
  plc_server: "plc.bsky-sandbox.dev",
  appview_server: "public.api.bsky.app",
  relay_server: "bgs.bsky-sandbox.dev",
  pds_host: "abyss.computer", # ignore pls for now
  multicodec_csv_path: "multicodec.csv"
