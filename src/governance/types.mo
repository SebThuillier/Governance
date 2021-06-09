import Nat "mo:base/Nat";
import Time "mo:base/Time";


public type Result = {
    #Error
    #Correct
}

public type StakeId = Nat;

public type Stake = {
    owner: Principal;
    quantity : Nat;
    stakePeriod : Nat;  //Number of days the user choose to stake for 
    startingTime : Time; 
    //Voting power = quantity + bonus where bonus is up to 100% for one month of staking. Values are meant to change. 
};

public type Vote = {
    #inFavor
    #against
};

public type Proposal = {
    #BurnTokens // These proposal are only possible if we have access to the ledger canister
    #MintToken // These proposal are only possible if we have access to the ledger canister
    #DistributeToken //Funds will be distribute from the "Community fund" 
}


public type DistributeToken = {
    proposer : Principal;
    var votesFor : Nat;
    var votesAgainst : Nat;
    var alreadyVoted : [Principal]; //We only know who voted but not what they voted
    var status : ProposalStatus;
    quantityToDistribute : Nat;
    recipient : Principal; //In case of an airdrop we want to specify the principal of "Airdrop" Canister (Hope its works like that)
    ttl : Int;
}


public type Error = {
    #balanceNotSufficient;
    #stakingPeriodNotCorrect;
    #unknownError;
    #stakeNotFound;
    #stakingPeriodNotFinished;
    #proposalNotFound;
    #proposalNotActive;
    #alreadyVoted;
}


public type ProposalStatus = {
    #active;
    #canceled;
    #defeated;
    #succeeded;
    #notFound;
}