# Migration Finance

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

But for testing you need to do this : 

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
forge create --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY src/MyContract.sol:MyContract -broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY 
```

## To verify a contract already deployed
```
forge verify-contract --chain-id 11155111 --verifier etherscan --api-key $ETHERSCAN_API_KEY <contract-address> <contract-name>
```

