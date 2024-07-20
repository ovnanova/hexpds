import Config

# example usage:
#  Application.get_env(:hexpds, :plc_server)

config :hexpds,
  plc_server: "plc.directory",
  appview_server: "api.bsky.app",
  relay_server: "bsky.network",
  # ignore pls for now
  pds_host: "abyss.computer",
  multicodec_csv_path: "multicodec.csv",
  admin_password: "admin",
  # or Ecto.Adapters.Postgres in production
  ecto_adapter: Ecto.Adapters.SQLite3,
  ecto_repos: [Hexpds.Database],
  port:
    (case Mix.env() do
       :prod -> 3999
       :dev -> 4000
       :test -> 4001
     end),
  # Example HS256 secret for access and refresh JWTs
  jwt_key:
    <<16_474_290_805_911_645_537_423_060_771_945_528_686_550_823_130_298_449_174_717_469_148_262_408_363_010::256>>

config :hexpds, Hexpds.Database,
  # Replace with Postgres URL in production!
  url: "sqlite3:///pds"

config :mnesia,
  dir: ~c".mnesia/#{Mix.env()}/#{node()}"
