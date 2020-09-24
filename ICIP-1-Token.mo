import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Word32 "mo:base/Word32";

// A user can be any principal or canister
type User = Principal;

// A Nat32 implies each canister can store 2**32 individual tokens
type TokenId = Nat32;

// Token amounts are unbounded
type Balance = Nat;

// Details for a token, eg. name, symbol, description, decimals.
// Metadata format TBD, possible option is JSON blob
type Metadata = Text;
type MetadataResponse = Result.Result<[Metadata], {
  #InvalidToken: TokenId;
}>;

// Request and responses for getBalance
type BalanceRequest = {
  user: User;
  tokenId: TokenId;
};
type BalanceResponse = Result.Result<[Balance], {
  #InvalidToken: TokenId;
}>;

// Request and responses for transfer
type TransferRequest = {
  from: User;
  to: User;
  tokenId: TokenId;
  amount: Balance;
};
type TransferResponse = Result.Result<(), {
  #Unauthorized;
  #InvalidDestination: User;
  #InvalidToken: TokenId;
  #InsufficientBalance;
}>;

// Request and responses for updateOperator
type OperatorAction = {
  #AddOperator;
  #RemoveOperator;
};
type OperatorRequest = {
  owner: User;
  operators: [(User, OperatorAction)];
};
type OperatorResponse = Result.Result<(), {
  #Unauthorized;
  #InvalidOwner: User;
}>;

// Request and responses for isAuthorized
type IsAuthorizedRequest = {
  owner: User;
  operator: User;
};
type IsAuthorizedResponse = [Bool];

// Utility functions for User and TokenId, useful when implementing containers
module User = {
  public let equal = Principal.equal;
  public let hash = Principal.hash;
};

module TokenId = {
  public func equal(id1 : TokenId, id2 : TokenId) : Bool { id1 == id2 };
  public func hash(id : TokenId) : Hash.Hash { Word32.fromNat(Nat32.toNat(id)) };
};

// Uniquely identifies a token
type TokenIdentifier = {
  canister: Token;
  tokenId: TokenId;
};

// Utility functions for TokenIdentifier
module TokenIdentifier = {
  // Tokens are equal if the canister and tokenId are equal
  public func equal(id1 : TokenIdentifier, id2 : TokenIdentifier) : Bool {
    Principal.fromActor(id1.canister) == Principal.fromActor(id2.canister)
    and id1.tokenId == id2.tokenId
  };
  // Hash the canister and xor with tokenId
  public func hash(id : TokenIdentifier) : Hash.Hash {
    Principal.hash(Principal.fromActor(id.canister)) ^ Word32.fromNat(Nat32.toNat(id.tokenId))
  };
  // Join the principal and id with a '_'
  public func toText(id : TokenIdentifier) : Text {
    Principal.toText(Principal.fromActor(id.canister)) # "_" # Nat32.toText(id.tokenId)
  };
};

/**
  A token canister that can hold many tokens.
*/
type Token = actor {
  /**
    Batch get balances.
    Any request with an invalid tokenId should cause the entire batch to fail.
    A user that has no token should default to 0.
  */
  getBalance: query (requests: [BalanceRequest]) -> async BalanceResponse;

  /**
    Batch get metadata.
    Any request with an invalid tokenId should cause the entire batch to fail.
  */
  getMetadata: query (tokenIds: [TokenId]) -> async MetadataResponse;

  /**
    Batch transfer.
    A request should fail if:
      - the caller is not authorized to transfer for the sender
      - the sender has insufficient balance
    Any request that fails should cause the entire batch to fail, and to
    rollback to the initial state.
  */
  transfer: shared (requests: [TransferRequest]) -> async TransferResponse;

  /**
    Batch update operator.
    A request should fail if the caller is not authorized to update operators
    for the owner.
    Any request that fails should cause the entire batch to fail, and to
    rollback to the initial state.
  */
  updateOperator: shared (requests: [OperatorRequest]) -> async OperatorResponse;

  /**
    Batch function to check if a user is authorized to transfer for an owner.
  */
  isAuthorized: query (requests: [IsAuthorizedRequest]) -> async IsAuthorizedResponse;
};