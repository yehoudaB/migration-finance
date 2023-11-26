# Teleport Aave V3 ( Aave Tools https://aave-tools.web.app )

### Configuration
for interactWithTeleportAaveV3 contract run
```
  forge install ChainAccelOrg/foundry-devops --no-commit
```


### Deploy contract locally from a fork url 

run : 
````
anvil --fork-url $SEPOLIA_RPC_URL
````

then :
    
````
make deploy
````

for testing from sepolia fork in one command you need to do this : 

```
 source .env 
 ```
 then
```
forge test --fork-url $SEPOLIA_RPC_URL -vvvv --mt <name-of-test-fonction>
```
equivalent to : 
```
  make test
``````


## deployement command example for seploia network

```
   make deploy ARGS="--network sepolia"
```

or with forge directly
```
source .env
````
then
```
forge create --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY src/MyContract.sol:MyContract  --verify --etherscan-api-key $ETHERSCAN_API_KEY 
```

## To verify a contract already deployed
```
forge verify-contract --chain-id 11155111 --watch --verifier etherscan --api-key $ETHERSCAN_API_KEY <contract-address> <contract-name>
```

for prepareTeleportAaveV3 contract example : 
```
forge verify-contract --chain-id 11155111 --watch --verifier etherscan --api-key $ETHERSCAN_API_KEY 0x049893EC86Ad3FAA67557410E2bae0c4190bAcA9  PrepareTeleportAaveV3   --constructor-args $(cast abi-encode "constructor(address,address,address)"  0x3e9708d80f7B3e43118013075F7e95CE3AB31F31 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951 0x65e71BeDf24b1418b39E4bbf106516cCd0e58508)    

```

for TeleportAaveV3 contract example : 
```
forge verify-contract --chain-id 137 --watch --verifier etherscan --api-key $POLYSCAN_API_KEY 0xeb075d205313a9B4427FB37dd14a8695B1436937  TeleportAaveV3   --constructor-args $(cast abi-encode "constructor(address,address)" 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb 0x9945852318056dC9EbAfdC3caC70d05e0fBa00F7)    

```


