require "http/client"
require "json"
require "option_parser"
require "system/user"
require "uri"

lib LibC
  fun getuid : UidT
end

query_type = ""
domain = ""
user = System::User.find_by id: LibC.getuid.to_s

op = OptionParser.parse do |parser|
  parser.banner = "flc - flare.io Credential Broweser Client"
  # with the -d option you can specify the domain
  # e.g. flc -d flare.io
  parser.on "-d", "--domain DOMAIN", "The domain to query" do |d|
    query_type = "domain"
    domain = d
  end

  parser.on "-h", "--help", "Show help - get more help for a specific action e.g. -a add" do
    puts parser
    exit
  end
end

if query_type == ""
  if ARGV.size != 0
    domain = ARGV[0]
    query_type = "domain"
  else
    puts op
    exit
  end
end

# check if the config file exists
# if not create it
config_dir = File.join(user.home_directory, ".config", "flc")

# create the config directory if it does not exist
Dir.mkdir(config_dir) unless Dir.exists?(config_dir)

config_file = File.join(config_dir, "api_key")
# create the config file if it does not exist
unless File.exists?(config_file)
  File.open(config_file, "w") do |f|
  end
end

tenant_id_file = File.join(config_dir, "tenant_id")
# create the config file if it does not exist
unless File.exists?(tenant_id_file)
  File.open(tenant_id_file, "w") do |f|
  end
end

# reading the api key from the confit file located in the ~/.config/flc/api_key
api_key = File.read(config_file).strip

if api_key == ""
  puts "No API key found. Please put them into ~/.config/flc/api_key"
  exit 1
end

# reading the tenant id from the confit file located in the ~/.config/flc/tenant_id
tenant_id = File.read(tenant_id_file).strip

if tenant_id == ""
  puts "No tenant id found. Please put them into ~/.config/flc/tenant_id"
  exit 1
end

# get the jwt token
client = HTTP::Client.new(URI.parse("https://api.flare.io"))
# client should use basic auth
client.basic_auth("", api_key)
response = client.post("/tokens/generate", body: "{\"tenant_id\": #{tenant_id}}")
jwt_token = JSON.parse(response.body)["token"]

# check if token has a value
if jwt_token == ""
  puts "No JWT token found. Please check your API key and tenant id"
  exit 1
end

# get the credentials
# example call with curl and domain iad.de: curl -H "Content-Type: application/json" -H "Cookie: token=eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2VtYWlsIjoicHdAZ3JlZW5oYXRzLmNvbSIsInVzZXJfaWQiOjExMDA2NywidGVuYW50X2lkIjoxMTMzNTcsIm9yZ2FuaXphdGlvbl9pZCI6OTIwNzQsImFwaV9rZXlfaWQiOjE0ODUxLCJzY29wZXMiOlsiYXV0aGVudGljYXRlZCIsImxlYWtzZGIiLCJyYXRlbGltaXRlZCIsImFwaWtleSIsImZpcmV3b3JrIl0sImlhdCI6MTcxNDE0MTU0MywiZXhwIjoxNzE0MTQ1MTQzfQ.n6pZhhZ0kOrMVx8Rx1ul2mziP-ZqYLaoEMpSniXxqI8VEYYMRJEPNr-Lhr7idVSlhn-JyDO0BE2kYQyZ502h5Q" https://api.flare.io/firework/v2/leaks/domains/iad.de/credentials\?size\=50\&include_subdomains\=true

client = HTTP::Client.new(URI.parse("https://api.flare.io"))
response = client.get("/firework/v2/leaks/domains/#{domain}/credentials?size=50&include_subdomains=true", headers: HTTP::Headers{"Cookie" => "token=#{jwt_token}"})
puts JSON.parse(response.body)
