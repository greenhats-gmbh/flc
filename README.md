# flare.io Credential Broweser Client
This tool is able to make requests to the flare.io API, specifically to the /firework/v2/leaks/domains/DOMAIN/credentials endpoint, to query for leaked credentials directly from the command line. 

## Installation
Just check out the releases for the precompiled binaries or build it from source (no external shards needed).

### Pre build binaries (linux)
```zsh
wget ...
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

At current stage only the domain search is implemented.

```
flc - flare.io Credential Browser Client
    -d, --domain DOMAIN              The domain to query (default first parameter)
    -i, --identity                   Only output the identity (unique)
    -s, --secret                     Only output the secret (unique)
    -n, --number NUMBER              Number of results to display (default 50)
    -h, --help                       Show help
```

### Examples

Query for a domain and display results as a table: `flc example.com`
Query for a domain and save only the unique passwords / hashes: `flc -d example.com -s > /dev/shm/credentials.txt`

## Development
Any contribution is welcome. Just make an isse or pull request.

## Contributing

1. Fork it (<https://github.com/your-github-user/flc/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request