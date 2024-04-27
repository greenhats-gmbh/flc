# This Crystal program is a command-line client for the flare.io Credential Browser API.
# It allows users to query credentials for a specific domain and output the results in various formats.

# Required dependencies
require "http/client"
require "json"
require "option_parser"
require "system/user"
require "uri"

# External library binding
lib LibC
  fun getuid : UidT
end

# Initialize variables
query_type = ""
value = ""
output_format = "table"
number_of_results = "50"
current_user = System::User.find_by(id: LibC.getuid.to_s)
verbose = false

def generate_jwt_token(api_key, tenant_id)
  # Generate JWT token using API key and tenant ID
  client = HTTP::Client.new(URI.parse("https://api.flare.io"))
  client.basic_auth("", api_key)
  response = client.post("/tokens/generate", body: "{\"tenant_id\": #{tenant_id}}")
  return JSON.parse(response.body)["token"].to_s
end

# Parse command-line options
option_parser = OptionParser.parse do |parser|
  parser.banner = "flc - flare.io Credential Browser Client"

  # Specify the domain to query with the -d option
  parser.on "-d", "--domain DOMAIN", "The domain to query (default first parameter)" do |d|
    query_type = "domain"
    value = d
  end

  # Specify the email address to query with the -e option
  parser.on "-e", "--email EMAIL", "The email address to query" do |e|
    query_type = "email"
    value = e
  end

  # Specify the password to query with the -p option
  parser.on "-p", "--password PASSWORD", "The password to query" do |p|
    query_type = "password"
    value = p
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

  # Show verbose output with the -v option
  parser.on "-v", "--verbose", "Show verbose output" do |v|
    verbose = true
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
    value = ARGV[0]
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

# Validate the domain or email address
case query_type
when "domain"
  # before making any requests to the API we need to make sure that the domain matches the regex of a valid domain name and do not contain any bad characters
  if value.match(/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$/).nil?
    puts "[!] Invalid domain name. Please provide a valid domain name."
    exit 1
  end
when "email"
  # before making any requests to the API we need to make sure that the email matches the regex of a valid email address and do not contain any bad characters
  if value.match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i).nil?
    puts "[!] Invalid email address. Please provide a valid email address."
    exit 1
  end
end


# make sure that provided number_of_results is a number
if number_of_results.match(/^\d+$/).nil?
  puts "[!] Invalid number of results. Please provide a valid number."
  exit 1
end

# check if a JWT token is already generated and not expired and stored in the config file  ~/.config/flc/token
token_file = File.join(config_dir, "token")
jwt_token = ""

if File.exists?(token_file)
  puts "[*] Token file found. Checking if token is valid ..." if verbose
  jwt_token = File.read(token_file).strip
  client = HTTP::Client.new(URI.parse("https://api.flare.io"))
  response = client.get("/tokens/test", headers: HTTP::Headers{"Authorization" => "Bearer #{jwt_token}"})
  if response.status_code != 200
    # if the token is expired or invalid, we need to generate a new one and store it in the config file
    puts "[*] Code seems to be invalid. Generating JWT new token..." if verbose
    jwt_token = generate_jwt_token(api_key, tenant_id)
    File.open(token_file, "w") { |file| file.puts jwt_token }
  else
    puts "[+] Token is valid." if verbose
    # checking if the token is expired (decoded token contains the expiration time)
    decoded_token = JSON.parse(Base64.decode_string(jwt_token.split(".")[1]))
    if Time.local.to_unix > decoded_token["exp"].to_s.to_i
      puts "[*] Token is expired. Generating new JWT token..." if verbose
      jwt_token = generate_jwt_token(api_key, tenant_id)
      File.open(token_file, "w") { |file| file.puts jwt_token }
    else
      puts "[+] Token is not expired." if verbose
    end
  end
else
  # if the token is not found, we need to generate a new one and store it in the config file
  puts "[*] No token file found. Generating new JWT token..." if verbose
  jwt_token = generate_jwt_token(api_key, tenant_id)
  File.open(token_file, "w") { |file| file.puts jwt_token }
end

# Check if JWT token is empty
if jwt_token == ""
  puts "[-] No JWT token found or generated. Please check your API key and tenant id"
  exit 1
end


client = HTTP::Client.new(URI.parse("https://api.flare.io"))
query = ""
case query_type
when "domain"
  puts "[*] Querying credentials for domain: #{value}" if verbose
  query = "/firework/v2/leaks/domains/#{value}/credentials?size=#{number_of_results}&include_subdomains=true"
when "email"
  puts "[*] Querying credentials for email: #{value}" if verbose
  query = "/firework/v2/leaks/emails/#{value}/credentials?size=#{number_of_results}&include_subdomains=true"
when "password"
  puts "[*] Querying credentials for password: #{value}" if verbose
  query = "/firework/v2/leaks/passwords/#{value}/credentials?size=#{number_of_results}&include_subdomains=true"
end

response = client.get(query, headers: HTTP::Headers{"Cookie" => "token=#{jwt_token}"})

# Check if the response is successful
if response.status_code != 200
  puts "[-] Error querying credentials: #{response.status_code}"
  exit
else
  puts "[+] Successfully queried credentials" if verbose
  credentials = JSON.parse(response.body)["items"].as_a
end

# Check if there are any credentials for the specified domain
if credentials.empty?
  puts "[-] No credentials found for #{query_type}: #{value}"
  exit
end

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

  puts "[+] Display #{credentials.size} (max: #{number_of_results}) credentials for #{query_type}: #{value}"
  puts "-" * (max_identity_name_length + max_hash_length + max_source_name + 5)
  puts "Identity".ljust(max_identity_name_length) + " | " + "Secret".ljust(max_hash_length) + " | " + "Source".ljust(max_source_name)
  puts "-" * (max_identity_name_length + max_hash_length + max_source_name + 5)

  credentials.each do |credential|
    identity_name = credential["identity_name"].to_s
    hash = credential["hash"].to_s
    puts identity_name.ljust(max_identity_name_length) + " | " + hash.ljust(max_hash_length) + " | " + credential["source"]["name"].to_s.ljust(max_source_name)
  end
end
