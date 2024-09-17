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
get_all_results = false
csv_export = false
csv_file = ""

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

  # Output the maximum number of results
  parser.on "-a", "--all", "Search for all credentials (default 50)" do |n|
    get_all_results = true
  end

  # output the data as csv
  parser.on "-c", "--csv FILEPATH", "Output all the data to the target file as CSV regardless of -i or the -s option" do |c|
    csv_export = true
    csv_file = c
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

if csv_export
  # ensure that a filename is given and writeable
  if csv_file.empty?
    puts "[!] No filename given for CSV export"
    exit 1
  end

  # check if the file already exists
  if File.exists?(csv_file)
    puts "[!] File #{csv_file} already exists. Do you want to overwrite it? (y/n)"
    answer = STDIN.gets.to_s.chomp
    if answer.downcase != "y"
      puts "[*] Exiting..."
      exit 1
    end
  end

  # create the file if it does not exist and exits with error if it fails
  begin
    File.open(csv_file, "w") {}
  rescue
    puts "[!] Error creating file #{csv_file}"
    exit 1
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
credentials = [] of JSON::Any
number_of_results = 50 # default number of results

case query_type
when "domain"
  puts "[*] Querying credentials for domain: #{value}" if verbose
  query = "/leaksdb/v2/credentials/by_domain/#{value}?size=#{number_of_results}"
when "email"
  puts "[*] Querying credentials for email: #{value}" if verbose
  query = "/leaksdb/identities/by_keyword/#{value}?size=#{number_of_results}"
when "password"
  puts "[*] Querying credentials for password: #{value}" if verbose
  query = "/leaksdb/identities/by_password/#{value}?size=#{number_of_results}"
end

# case query type is email or password we need to change the query to get all the results
if get_all_results && (query_type == "email" || query_type == "password")
  query = query.gsub("size=#{number_of_results}", "size=10000")
end

# Query the credentials based on the specified query type
if get_all_results && query_type == "domain"
  puts "[*] Querying credentials for domain: #{value} (multiple requests)" if verbose
  # patching the query to size=100 to get the maximum number of results per page
  query = query.gsub("size=#{number_of_results}", "size=100")

  while true
    response = client.get(query, headers: HTTP::Headers{"Cookie" => "token=#{jwt_token}"})
    if response.status_code != 200
      puts "[-] Error querying credentials: #{response.status_code}"
      exit
    end
    response_body = JSON.parse(response.body)

    break if response_body["items"].as_a.empty?
    puts "[+] Successfully queried #{response_body["items"].as_a.size} credentials" if verbose
    credentials += response_body["items"].as_a

    # patch the query to include the search_after parameter e.g. search_after=#{response_body["next"]}
    # check if query has already search_after parameter then replace it with the new one otherwise add it to the query
    query = query.includes?("search_after") ? query.gsub(/search_after=[^&]+/, "search_after=#{response_body["next"]}") : query + "&search_after=#{response_body["next"]}"
  end
else
  response = client.get(query, headers: HTTP::Headers{"Cookie" => "token=#{jwt_token}"})

  # Check if the response is successful
  if response.status_code != 200
    puts "[-] Error querying credentials: #{response.status_code}"
    exit
  else
    puts "[+] Successfully queried credentials" if verbose
    # parse the response body depending on the query type
    case query_type
    when "domain"
      credentials = JSON.parse(response.body)["items"].as_a

    when "email"
      json_data = JSON.parse(response.body)
      # if response is empty then exit
      unless json_data.as_a.empty?
        passwords = json_data.as_a.first["passwords"].as_a
        # inject the identity name into the credentials
        credentials = passwords.map { |password| {"identity_name" => json_data.as_a.first["name"], "hash" => password["hash"], "imported_at" => password["imported_at"], "source" => password["source"]} }
      end
    when "password"
      # sample data
      json_data = JSON.parse(response.body)
      json_data.as_a.each do |identity|
        credentials += identity["passwords"].as_a.map { |password| {"identity_name" => identity["name"], "hash" => password["hash"], "imported_at" => password["imported_at"], "source" => password["source"]} }
      end
    end
  end
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
  max_imported_at_length = credentials.map { |credential| credential["imported_at"].to_s.size }.max
  max_identity_name_length = credentials.map { |credential| credential["identity_name"].to_s.size }.max
  max_hash_length = credentials.map { |credential| credential["hash"].to_s.size }.max
  max_source_name = credentials.map { |credential| credential["source"]["name"].to_s.size }.max

  puts "[+] Display #{credentials.size} (max: #{ get_all_results ? "∞" : number_of_results }) credentials for #{query_type}: #{value}"
  puts "-" * (max_imported_at_length + max_identity_name_length + max_hash_length + max_source_name + 5)
  puts "First seen".ljust(max_imported_at_length) + " | " + "Identity".ljust(max_identity_name_length) + " | " + "Secret".ljust(max_hash_length) + " | " + "Source".ljust(max_source_name)
  puts "-" * (max_imported_at_length + max_identity_name_length + max_hash_length + max_source_name + 5)

  credentials.each do |credential|
    identity_name = credential["identity_name"].to_s
    hash = credential["hash"].to_s
    puts credential["imported_at"].to_s.ljust(max_source_name) + " | " + identity_name.ljust(max_identity_name_length) + " | " + hash.ljust(max_hash_length) + " | " + credential["source"]["name"].to_s.ljust(max_source_name)
  end
end

if csv_export
  # write the data to the csv file
  File.open(csv_file, "w") do |file|
    file.puts "first_seen,identity,secret,source"
    credentials.each do |credential|
      file.puts "#{credential["imported_at"]},#{credential["identity_name"]},#{credential["hash"]},#{credential["source"]["name"]}"
    end
  end
end
