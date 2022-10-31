ExUnit.start(capture_log: true)

Application.put_env(:tesla, :adapter, Tesla.Mock)
