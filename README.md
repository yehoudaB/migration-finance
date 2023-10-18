# Migration Finance

### Configuration
for interaction contract run
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
 forge test --fork-url $SEPOLIA_RPC_URL -vvvv 
```
equivalent to : 
```
  make test
``````


