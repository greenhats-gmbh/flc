# flare.io Credential Browser Client
This tool is able to make requests to the api.flare.io API, specifically to the /firework/v2/leaks/.../credentials endpoint, to query for leaked credentials directly from the command line. 

## Installation
Just check out the releases for the precompiled binaries or build it from source (no external shards needed).

### Pre build binaries (linux)
```zsh
wget https://github.com/greenhats-gmbh/flc/releases/download/linux_x64/flc
chmod +x flc
./flc
```

### From source
```zsh
git clone https://github.com/greenhats-gmbh/flc
cd flc
shards build
```

## Usage
You must ensure that you meet the requirements. You need full access to the platform and the credentials browser feature (beta). Then you need to create an API key and know your tendent_id. Please refer to the official documentation: https://docs.flare.io/authentication-and-endpoints

API key => `~/.config/flc/api_key`
Tenant ID => `~/.config/flc/tenant_id`

```
flc - flare.io Credential Browser Client
    -d, --domain DOMAIN              The domain to query (default first parameter)
    -x, --exclude-subdomains         Exclude subdomains (included by default)
    -e, --email EMAIL                The email address to query
    -p, --password PASSWORD          The password to query
    -i, --identity                   Only output the identity (unique)
    -s, --secret                     Only output the secret (unique)
    -a, --all                        Search for all credentials (default 50)
    -v, --verbose                    Show verbose output
    -h, --help                       Show help
```

### Examples

Query for a domain and display results as a table: `flc example.com`

Query for a domain and save only the unique passwords / hashes: `flc -d example.com -s > /dev/shm/credentials.txt`


```zsh
./flc -d example.com -a
[+] Display 2 (max: ∞)) credentials for domain: example.com
---------------------------------------------------------------------------------------
First seen                       | Identity          | Secret    | Source
---------------------------------------------------------------------------------------
2024-04-10T09:09:09.840338+00:00 | bob@example.com   | Hackerman | Nice Combolist
2023-07-20T19:20:31.696547+00:00 | alice@example.com | Password7 | 2027 June Combolists
```

```zsh
./flc -e bob@example.com
[+] Display 1 (max: 50) credentials for email: bob@example.com
---------------------------------------------------------------------------------
First seen                       | Identity          | Secret    | Source
---------------------------------------------------------------------------------
2024-04-10T09:09:09.840338+00:00 | bob@example.com   | Hackerman | Nice Combolist
```

```zsh
./flc -e bob@example.com -s
Hackerman
```

```zsh
./flc -p Hackerman
[+] Display 50 (max: 50) credentials for password: Hackerman
---------------------------------------------------------------------------------
First seen                       | Identity          | Secret    | Source
---------------------------------------------------------------------------------
2024-04-10T09:09:09.840338+00:00 | bob@example.com   | Hackerman | Nice Combolist
...
```

## Development
Any contribution is welcome. Just make an issue or pull request.

## Contributing

1. Fork it (<https://github.com/your-github-user/flc/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
