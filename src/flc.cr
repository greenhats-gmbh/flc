# FILEPATH: /home/flx/flc/src/flc.cr

# This Crystal program is a command-line client for the flare.io Credential Browser API.
# It allows users to query credentials for a specific domain and output the results in various formats.

# Required dependencies
require "http/client"
require "json"
require "option_parser"
require "system/user"
require "uri"
require "ncurses"

# External library binding
lib LibC
  fun getuid : UidT
end

# Initialize variables
query_type = ""
domain = ""
output_format = "table"
number_of_results = "50"
current_user = System::User.find_by(id: LibC.getuid.to_s)

# Parse command-line options
option_parser = OptionParser.parse do |parser|
  parser.banner = "flc - flare.io Credential Browser Client"

  # Specify the domain to query with the -d option
  parser.on "-d", "--domain DOMAIN", "The domain to query (default first parameter)" do |d|
    query_type = "domain"
    domain = d
  end

  # Only output the identity (unique) with the -i option
  parser.on "-i", "--identity", "Only output the identity (unique)" do |o|
    output_format = "i"
  end

  # Only output the secret (unique) with the -s option
  parser.on "-s", "--secret", "Only output the secret (unique)" do |s|
    output_format = "s"
  end

  # option for the number of results to display
  parser.on "-n", "--number NUMBER", "Number of results to display (default 50)" do |n|
    number_of_results = n
  end

  # Show help and exit with the -h option
  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end
end

# Handle missing command-line options
if query_type.empty?
  if ARGV.size != 0
    domain = ARGV[0]
    query_type = "domain"
  else
    puts option_parser
    exit
  end
end

# Check and create the config directory and files
config_dir = File.join(current_user.home_directory, ".config", "flc")
Dir.mkdir(config_dir) unless Dir.exists?(config_dir)

config_file = File.join(config_dir, "api_key")
File.open(config_file, "w") {} unless File.exists?(config_file)

tenant_id_file = File.join(config_dir, "tenant_id")
File.open(tenant_id_file, "w") {} unless File.exists?(tenant_id_file)

# Read the API key and tenant ID from config files
api_key = File.read(config_file).strip
if api_key.empty?
  puts "[*] No API key found. Please put them into ~/.config/flc/api_key"
  exit 1
end

tenant_id = File.read(tenant_id_file).strip
if tenant_id.empty?
  puts "[*] No tenant id found. Please put them into ~/.config/flc/tenant_id"
  exit 1
end

# before making any requests to the API we need to make sure that the domain matches the regex of a valid domain name and do not contain any bad characters
if domain.match(/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$/).nil?
  puts "[!] Invalid domain name. Please provide a valid domain name."
  exit 1
end

# make sure that provided number_of_results is a number
if number_of_results.match(/^\d+$/).nil?
  puts "[!] Invalid number of results. Please provide a valid number."
  exit 1
end

# Generate JWT token using API key and tenant ID
client = HTTP::Client.new(URI.parse("https://api.flare.io"))
client.basic_auth("", api_key)
response = client.post("/tokens/generate", body: "{\"tenant_id\": #{tenant_id}}")
jwt_token = JSON.parse(response.body)["token"]

# Check if JWT token is empty
if jwt_token == ""
  puts "[*] No JWT token found. Please check your API key and tenant id"
  exit 1
end

# Query credentials for the specified domain
client = HTTP::Client.new(URI.parse("https://api.flare.io"))
response = client.get("/firework/v2/leaks/domains/#{domain}/credentials?size=#{number_of_results}&include_subdomains=true", headers: HTTP::Headers{"Cookie" => "token=#{jwt_token}"})
credentials = JSON.parse(response.body)["items"].as_a

# Output the results based on the specified format
case output_format
when "i"
  # Output unique identities
  unique_identities = credentials.map { |credential| credential["identity_name"] }.uniq
  unique_identities.each { |identity| puts identity.to_s }
when "s"
  # Output unique secrets
  unique_secrets = credentials.map { |credential| credential["hash"] }.uniq
  unique_secrets.each { |secret| puts secret.to_s }
else
  # Output results in table format
  max_identity_name_length = credentials.map { |credential| credential["identity_name"].to_s.size }.max
  max_hash_length = credentials.map { |credential| credential["hash"].to_s.size }.max
  max_source_name = credentials.map { |credential| credential["source"]["name"].to_s.size }.max

  puts "[+] Display #{credentials.size} (max: #{number_of_results}) credentials for domain: #{domain}"
  puts "-" * (max_identity_name_length + max_hash_length + max_source_name + 5)
  puts "Identity".ljust(max_identity_name_length) + " | " + "Secret".ljust(max_hash_length) + " | " + "Source".ljust(max_source_name)
  puts "-" * (max_identity_name_length + max_hash_length + max_source_name + 5)

  credentials.each do |credential|
    identity_name = credential["identity_name"].to_s
    hash = credential["hash"].to_s
    puts identity_name.ljust(max_identity_name_length) + " | " + hash.ljust(max_hash_length) + " | " + credential["source"]["name"].to_s.ljust(max_source_name)
  end
end
