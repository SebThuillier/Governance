import Types "./types";
import Principal "mo:base/Principal";
import Token "??????" //TODO : Where ?
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";


actor class StakeLedger(tokenLedgerPid : Principal) = SL {
    type Stake = Stake.Stake;
    type StakeID = Types.StakeId;
    type Result = Types.Result;

    //Used to assign a unique ID to each stake.
    stable var stakeCount = 0;
    //Used to assign a unique ID to each proposal.
    stable var proposalcount = 0;

    //Used to keep track of the total number of tokens staked.

    stable var totalStake = 0;

    let tokenLedger = actor (Principal.toText(tokenLedgerPid)) : Token.Token;

    let userToStakeIds = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal , Principal.hash);
    let stakeIdstoStake = HashMap.HashMap<Nat, Stake>(1, Nat.equal, Hash.hash);
    var proposals : [var Proposal] = [var]; //Problem ? proposals is not stable but the count is 

    func me() : Principal {
        Principal.fromActor(SL);
    }


    public shared(msg) func createStake(quantity:Nat, period:Nat) : async Result {
        if( period == 0 || period > 30 ) {
            return (#Error #StakigPeriodNotCorrect)
        }
        else {
            //Caller must have enough tokens 
        switch(await tokenLedger.balanceOf(msg.caller))  {
            // Is this the correct method ?
            case(null) return(#Error #BalanceNotSufficient);
            case(?balance) {
                if(balance < quantity) {
                    return (#Error #BalanceNotSufficient)
                };
            } 
        };
        if (not 
            (await 
                tokenLedger.transferFrom(
                    (msg.caller),
                    me(),
                    quantity
                )
            )) {
                return (#Error #UnknownError)
            };

            userToStakeIds.put(msg.caller, stakeCount);
            stakeIdstoStake.put(
                stakeCount,
                newStake(msg.caller,quantity,period,Time.now())
            );

            stakeCount +=1;
            totalStake += quantity;
            return (#Correct);
    }

    public shared (msg) func dissolveStake(idStake : StakeId , user:Principal) : Async Result {
        switch(stakeIdstoStake.get(msg.caller)) {
        
            case(null) return (#Error #StakeNotFound)
            case(?stake) {
                if((Time.now() - (stake.startingTime + stake.stakePeriod * 1000000000 * 86400)) < 0 ) {
                    return (#Error #StakingPeriodNotFinished)
                };
                if (not (await tokenLedger.transfer(PrincipalOftheCanister, Principal of the User, QuantityInTHeSTAKE))) {
                    return (#Error #UnknownError)
                };
                switch(userToStakeIds.get(user)) {
                    case (null) return (#Error #StakeNotFound)
                    case (?stakeList) {
                        func notEqual (n : Nat) : Bool {
                            return (n !== idStake)
                        };
                        let newStakeList = Array.filter(stakeList, notEqual); //Returns the stakeList without the StakeId we want to remove
                        userToStakeIds.put(user,newStakeList);
                        stakeIdstoStake.remove(idStake);
                        stakeCount -= 1;
                        totalStake -= stake.quantity;
                    }
                }    
            }
        }
    }

    public shared (msg) func createNewDistributeProposal (recipient: Principal , quantity : Nat) : async Result {
        let newProposal : DistributeToken = _newProposeDistribute(msg.caller,quantity,recipient);
    
        proposals := Array.thaw<Proposal>(Array.append<Proposal>(Array.freeze<Proposal>(proposals), [newProposal]))
        proposalcount +=1;
        return (#Correct);
    } //Do we want a cost to a new proposal ? Is everyone able to create a newDistributeProposal ?

    // The parameter for representing the choice of the user for this proposal : if it's true then he decided to vote FOR the proposal if it's false he has voted AGAINST.
    public shared (msg) func voteOnProposal (proposalId : Nat, vote : Bool) : async Result { 
       switch(_checkProposal(proposalId)) {
           case(#active) {
               let prop = proposals[proposalId];
               switch (vote) {
                   case (true) prop.votesFor += _votingPowerUser[msg.caller];
                   case (false) prop.votesAgainst += _votingPowerUser[msg.caller];
               };
               prop.alreadyVoted := Array.thaw<Principal>(Array.append<Principal>(Array.freeze<Principal>(prop.alreadyVoted, [msg.caller]]));
               proposals[proposalId] := prop;
               return (#Correct);
           };
           case(_) #Error(#proposalNotActive);
       }
    };

    public func checkProposal(proposalId) : async ProposalStatus {
        _checkProposal(proposalId);
    }

    // Internal helper functions 

    func _newStake(
        owner : Principal,
        quantity : Nat,
        stakePeriod : Nat, 
        startingTime : Time,
    ) : Stake {
        owner = owner;
        quantity = quantity;
        stakePeriod = stakePeriod;
        startingTime = startingTime;
    };


    func _votingPowerStake (id: StakeID) : Nat {
        let stake = stakeIdstoStake.get(id);
        case (null) return 0; // Or stake not found ?
        case (?stake) return {stake.quantity + (stakePeriod/30) * 100 }
    };

    func _votingPowerUser (id : Principal) : Nat {
        let allStakeIdsUser = userToStakeIds.get(id);
        var count = 0;
        const nbStake = stakeIdstoStake.size();
        let iter = Iter.range(0,nbStake-1);
        for (x in iter) {
            count = count + votingPowerStake(allStakeIdsUser[x]);
        }
        return count;
    };

    func _newProposeDistribute (proposer:Principal, quantity : Nat, recipient : Principal) : Proposal {
        {
            proposer =  proposer;
            var votesFor = 0;
            var votesAgainst = 0;
            var alreadyVoted = [];
            var status = #active;
            quantityToDistribute = quantity;
            recipient = recipient;
            ttl = Time.now() + (24 * 3600 * 1000_000_000);
        }
    };

    func  _checkProposal(propId : Nat) : ProposalStatus {
        if(proposals.size()< propId) return #proposalNotFound;
        let prop = proposals[propId];
        let status = switch (prop.status) {
        case (#active) {
            if (Time.now() > prop.ttl) {
            let outcome = Float.div(
                Float.fromInt(prop.votesFor),
                (Float.fromInt(prop.votesFor) + Float.fromInt(prop.votesAgainst))
                );
            if (outcome > voteThreshold) {
                prop.status := #succeeded;
                proposals[propNum] := prop;
                #succeeded
            } else {
                prop.status := #defeated;
                proposals[propNum] := prop;
                #defeated
            }
            } else {
            #active
            }
        };
        case (anythingElse) anythingElse;
        };

        (status)
  };
    


}

