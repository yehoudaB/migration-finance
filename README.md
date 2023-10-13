# Migration Finance

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
 forge test --fork-url $(SEPOLIA_RPC_URL) -vvv 
```
equivalent to : 
```
  make test
``````


