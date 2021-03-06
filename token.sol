pragma solidity ^0.4.21;

/*
    Owned contract interface
*/
contract IOwned {
    // this function isn't abstract since the compiler emits automatically generated getter functions as external
    function owner() public pure returns (address) { owner; }

    function transferOwnership(address _newOwner) public;
    function acceptOwnership() public;
}

/*
    Provides support and utilities for contract ownership
*/
contract Owned is IOwned {
    address public owner;
    address public newOwner;

    event OwnerUpdate(address _prevOwner, address _newOwner);

    /**
        @dev constructor
    */
    function Owned() public {
        owner = msg.sender;
    }

    // allows execution by the owner only
    modifier ownerOnly {
        assert(msg.sender == owner);
        _;
    }

    /**
        @dev allows transferring the contract ownership
        the new owner still needs to accept the transfer
        can only be called by the contract owner

        @param _newOwner    new contract owner
    */
    function transferOwnership(address _newOwner) public ownerOnly {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    /**
        @dev used by a new owner to accept an ownership transfer
    */
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = 0x0;
    }
}

contract Whitelist is Owned {
    
    // List of approved investors
    mapping(address => bool) private approvedInvestorList;
    
    /**
     * Functions with this modifier check the validity of address is investor
     */
    modifier validInvestor() {
        require(approvedInvestorList[msg.sender]);
        _;
    }
    
    modifier validInvestorAddress(address _address) {
        require(approvedInvestorList[_address]);
        _;
    }
    
    /**
     * @dev function to check if an address is in whitelist or not 
     */
    function isApprovedInvestor(address _addr) public constant returns (bool) {
        return approvedInvestorList[_addr];
    }
    
    /**
     * @dev add list of investors to the whitelist 
     * @param newInvestorList Array of addresses of investors to be added
     */
    function addInvestorList(address[] newInvestorList) ownerOnly public {
        for (uint256 i = 0; i < newInvestorList.length; i++) {
            approvedInvestorList[newInvestorList[i]] = true;
        }
    }

    /**
     * @dev remove list of investors from the whitelist 
     * @param investorList Array of addresses of investors to be removed
     */
    function removeInvestorList(address[] investorList) ownerOnly public {
        for (uint256 i = 0; i < investorList.length; i++) {
            approvedInvestorList[investorList[i]] = false;
        }
    }
}

/*
    Utilities & Common Modifiers
*/
contract Utils {
    /**
        constructor
    */
    function Utils() public {
    }

    // validates an address - currently only checks that it isn't null
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    // verifies that the address is different than this contract address
    modifier notThis(address _address) {
        require(_address != address(this));
        _;
    }

    // Overflow protected math functions

    /**
        @dev returns the sum of _x and _y, asserts if the calculation overflows

        @param _x   value 1
        @param _y   value 2

        @return sum
    */
    function safeAdd(uint256 _x, uint256 _y) internal pure returns (uint256) {
        uint256 z = _x + _y;
        assert(z >= _x);
        return z;
    }

    /**
        @dev returns the difference of _x minus _y, asserts if the subtraction results in a negative number

        @param _x   minuend
        @param _y   subtrahend

        @return difference
    */
    function safeSub(uint256 _x, uint256 _y) internal pure returns (uint256) {
        assert(_x >= _y);
        return _x - _y;
    }

    /**
        @dev returns the product of multiplying _x by _y, asserts if the calculation overflows

        @param _x   factor 1
        @param _y   factor 2

        @return product
    */
    function safeMul(uint256 _x, uint256 _y) internal pure returns (uint256) {
        if (_x == 0) return 0;
        uint256 z = _x * _y;
        assert(_x == 0 || z / _x == _y);
        return z;
    }
}

/*
    ERC20 Standard Token interface
*/
contract IERC20Token {
    // these functions aren't abstract since the compiler emits automatically generated getter functions as external
    function name() public pure returns (string) { name; }
    function symbol() public pure returns (string) { symbol; }
    function decimals() public pure returns (uint8) { decimals; }
    function totalSupply() public pure returns (uint256) { totalSupply; }
    function balanceOf(address _owner) public pure returns (uint256 balance) { _owner; balance; }
    function allowance(address _owner, address _spender) public pure returns (uint256 remaining) { _owner; _spender; remaining; }

    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
}

/*
    Token Holder interface
*/
contract ITokenHolder is IOwned {
    function withdrawTokens(IERC20Token _token, address _to, uint256 _amount) public;
}

/*
    We consider every contract to be a 'token holder' since it's currently not possible
    for a contract to deny receiving tokens.

    The TokenHolder's contract sole purpose is to provide a safety mechanism that allows
    the owner to send tokens that were sent to the contract by mistake back to their sender.
*/
contract TokenHolder is ITokenHolder, Owned, Utils {
    /**
        @dev constructor
    */
    function TokenHolder() public {
    }

    /**
        @dev withdraws tokens held by the contract and sends them to an account
        can only be called by the owner

        @param _token   ERC20 token contract address
        @param _to      account to receive the new amount
        @param _amount  amount to withdraw
    */
    function withdrawTokens(IERC20Token _token, address _to, uint256 _amount)
        public
        ownerOnly
        validAddress(_token)
        validAddress(_to)
        notThis(_to)
    {
        assert(_token.transfer(_to, _amount));
    }
}

/**
    ERC20 Standard Token implementation
*/
contract ERC20Token is IERC20Token, Utils {
    string public standard = "TALO Token 0.1";
    string public name = "";
    string public symbol = "";
    uint8 public decimals = 0;
    uint256 public totalSupply = 0;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
        @dev constructor

        @param _name        token name
        @param _symbol      token symbol
        @param _decimals    decimal points, for display purposes
    */
    function ERC20Token(string _name, string _symbol, uint8 _decimals) public {
        require(bytes(_name).length > 0 && bytes(_symbol).length > 0); // validate input

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /**
        @dev send coins
        throws on any error rather then return a false flag to minimize user errors

        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, false if it wasn't
    */
    function transfer(address _to, uint256 _value)
        public
        validAddress(_to)
        returns (bool success)
    {
        balanceOf[msg.sender] = safeSub(balanceOf[msg.sender], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
        @dev an account/contract attempts to get the coins
        throws on any error rather then return a false flag to minimize user errors

        @param _from    source address
        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, false if it wasn't
    */
    function transferFrom(address _from, address _to, uint256 _value)
        public
        validAddress(_from)
        validAddress(_to)
        returns (bool success)
    {
        allowance[_from][msg.sender] = safeSub(allowance[_from][msg.sender], _value);
        balanceOf[_from] = safeSub(balanceOf[_from], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
        @dev allow another account/contract to spend some tokens on your behalf
        throws on any error rather then return a false flag to minimize user errors

        also, to minimize the risk of the approve/transferFrom attack vector
        (see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/), approve has to be called twice
        in 2 separate transactions - once to change the allowance to 0 and secondly to change it to the new allowance value

        @param _spender approved address
        @param _value   allowance amount

        @return true if the approval was successful, false if it wasn't
    */
    function approve(address _spender, uint256 _value)
        public
        validAddress(_spender)
        returns (bool success)
    {
        // if the allowance isn't 0, it can only be updated to 0 to prevent an allowance change immediately after withdrawal
        require(_value == 0 || allowance[msg.sender][_spender] == 0);

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
}

contract TALOToken is ERC20Token, TokenHolder {
    
    ///////////////////////////////////////// VARIABLE INITIALIZATION /////////////////////////////////////////

    uint256 constant public TALO_UNIT = 10 ** 18;
    uint256 public totalSupply = (10**9) * TALO_UNIT; // 1,000,000,000 Token

    // Address of the crowdfund
    address public taloCrowdTokenSaleAddress = 0x0;
    uint256 constant public taloCrowdfundAllocation = 400 * 10**6 * TALO_UNIT; // 40%
    uint256 constant public crowdTokenSaleStartTime = 1527465600; // 05/28/2018 @ 12:00am (UTC)
    uint256 constant public crowdTokenSaleEndTime = 1538351999;   // 09/30/2018 @ 11:59pm (UTC)

    // TALO Advisor addresses
    uint256 constant public taloAdvisorAllocation = 50 * 10**6 * TALO_UNIT; // 5%
    address[] public advisorAddresses;                                          
    uint256[] public advisorAllocations;                                   
    
    // TALO Team address
    address public taloTeamAddress;                                             
    uint256 constant public taloTeamAllocation = 150 * 10**6 * TALO_UNIT; // 15%
    
    // TALO Foundation address
    address public taloFoundationAddress;
    uint256 constant public taloFoundationAllocation = 350 * 10**6 * TALO_UNIT; // 35%. Treasury reserve + Ecosystem Building - 5% Pre-allocation
    uint256 constant public taloFoundationPreAllocation = 50 * 10**6 * TALO_UNIT; // 5%. Pre-allocation for TALO Foundation to run the Marketing
    
    // Maximum Token preserved for bonus. Based on bonus formula calculating
    uint256 constant public maximumBonusAllocation = 144 * 10**6 * TALO_UNIT;
    
    // List of approved addresses for early transferring
    mapping(address => bool) private approvedTransferringList;
    
    // List of locked up addresses to prevent from transferring TALO
    mapping(address => bool) private lockedTransferringList;
    
    // Flag to allow early transferring 
    bool internal isEarlyTransferringAllowed = false;
    
    // Flag to allow token tranferring to public, token can be transferred freely without any limitation from the lock list
    bool internal isReleasedToPublic = false;                                    


    // Variables
    uint256 public totalAllocatedForBonus = 0;                                   // Counter to keep track of token allocation for bonus during the private sale
    
    uint256 public totalAllocatedToAdvisors = 0;                                 // Counter to keep track of advisor token allocation
    uint256 public totalAllocatedToTeam = 0;                                     // Counter to keep track of team token allocation
    uint256 public totalAllocatedToFoundation = 0;                               // Counter to keep track of Foundation token allocation
    uint256 public totalPreAllocatedToFoundation = 0;                            // Counter to keep track of Foundation token pre-allocation 
    
    uint256 public totalAllocated = 0;                                           // Counter to keep track of overall token allocation
    
    uint256 internal teamTranchesReleased = 0;                                   // Track how many tranches (allocations of 12.5% team tokens) have been released
    uint256 internal maxTeamTranches = 8;                                        // 8 tranches for the team to get the token, 12.5% each, 1 tranch = 90 days


    ///////////////////////////////////////// MODIFIERS /////////////////////////////////////////

    // TALO Team timelock 
    modifier threeMonthTimeLock() {
        require(now >= crowdTokenSaleEndTime + 3 * 30 days);
        _;
    }

    // TALO Advisor timelock    
    modifier sixMonthTimeLock() {
        require(now >= crowdTokenSaleEndTime + 6 * 30 days);
        _;
    }

    // Function only accessible by the Priate Sale contract
    modifier crowdTokenSaleContractOnly() {
        require(msg.sender == taloCrowdTokenSaleAddress);
        _;
    }
    
    // After crowd token sale timelock
    modifier afterCrowdTokenSale() {
        require(now >= crowdTokenSaleEndTime);
        _;
    }
    
    /**
        @dev set the crowd token sale address for TALO, set balance for the smart contract
        equal to the Total allocation for crowdfund.
    */
    function setCrowdTokenSaleAddress(address _taloCrowdTokenSaleAddress) validAddress(_taloCrowdTokenSaleAddress) ownerOnly public returns (bool success) {
        require(taloCrowdTokenSaleAddress == 0x0);
        taloCrowdTokenSaleAddress = _taloCrowdTokenSaleAddress;
        balanceOf[taloCrowdTokenSaleAddress] = taloCrowdfundAllocation;
        emit Transfer(0x0, taloCrowdTokenSaleAddress, taloCrowdfundAllocation);
        return true;
    }
    
    /**
        @dev set advisor lists, the allocations for advisor can not exceed the limit for Advisors
    */
    function setAdvisorAddressesAndAllocations(address[] _advisorAddresses, uint256[] _advisorAllocations) ownerOnly public returns (bool success) {
        require(totalAllocatedToAdvisors == 0);
        require(_advisorAddresses.length == _advisorAllocations.length);
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < _advisorAllocations.length; ++i) {
            require(_advisorAddresses[i] != 0x0);
            totalAllocation = safeAdd(totalAllocation, _advisorAllocations[i]);
        }
        require(totalAllocation <= taloAdvisorAllocation);
        advisorAddresses = _advisorAddresses;
        advisorAllocations = _advisorAllocations;
        return true;
    }
    
    /**
     * @dev add list of addresses which are allowed for early transferring
     * @param newAddressList Array of addresses
     */
    function addApprovedAddressesForTransferring(address[] newAddressList) ownerOnly public {
        for (uint256 i = 0; i < newAddressList.length; i++) {
            approvedTransferringList[newAddressList[i]] = true;
        }
    }

    /**
     * @dev remove list of addresses which are allowed for early transferring
     * @param addressList Array of addresses
     */
    function removeApprovedAddressesForTransferring(address[] addressList) ownerOnly public {
        for (uint256 i = 0; i < addressList.length; i++) {
            approvedTransferringList[addressList[i]] = false;
        }
    }
    
    /**
     * @dev add list of addresses which are locked up from transferring
     * @param newAddressList Array of addresses
     */
    function addLockedUpAddressesForTransferring(address[] newAddressList) ownerOnly public {
        for (uint256 i = 0; i < newAddressList.length; i++) {
            lockedTransferringList[newAddressList[i]] = true;
        }
    }

    /**
     * @dev remove list of addresses which are locked up from transferring
     * @param addressList Array of addresses
     */
    function removeLockedUpAddressesForTransferring(address[] addressList) ownerOnly public {
        for (uint256 i = 0; i < addressList.length; i++) {
            lockedTransferringList[addressList[i]] = false;
        }
    }

    ///////////////////////////////////////// CONSTRUCTOR /////////////////////////////////////////

    /**
        @dev constructors
    */
    function TALOToken(address _taloTeamAddress, address _taloFoundationAddress)
    ERC20Token("TALO Coin", "TALO", 18) public
    {
        taloTeamAddress = _taloTeamAddress;
        taloFoundationAddress = _taloFoundationAddress;
    }

    ///////////////////////////////////////// ERC20 OVERRIDE /////////////////////////////////////////

    /**
        @dev send coins
        throws on any error rather then return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if ( isReleasedToPublic 
                ||  ( (isTransferAllowed() == true || msg.sender == taloCrowdTokenSaleAddress || approvedTransferringList[msg.sender])
                    && !lockedTransferringList[msg.sender] ) ) {
            assert(super.transfer(_to, _value));
            return true;
        }
        revert();        
    }

    /**
        @dev an account/contract attempts to get the coins
        throws on any error rather then return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _from    source address
        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if ( isReleasedToPublic 
                ||  ( (isTransferAllowed() == true || _from == taloCrowdTokenSaleAddress || approvedTransferringList[_from])
                    && !lockedTransferringList[_from] ) ) {
            assert(super.transferFrom(_from, _to, _value));
            return true;
        }
        revert();
    }

    ///////////////////////////////////////// ALLOCATION FUNCTIONS /////////////////////////////////////////

    /**
        @dev Release TALO Token to TALO Team based on 8 tranches:
        - After 90 days: 12.5%
        - After 180 days: 12.5% more
        - After 270 days: 12.5% more
        - After 360 days: 12.5% more
        - After 450 days: 12.5% more
        - After 540 days: 12.5% more
        - After 630 days: 12.5% more
        - After 720 days: 12.5% more
        @return true if successful, throws if not
    */
    function releaseTALOTeamTokens() threeMonthTimeLock ownerOnly public returns(bool success) {
        require(totalAllocatedToTeam < taloTeamAllocation);

        uint256 taloTeamAlloc = taloTeamAllocation / 1000;
        uint256 currentTranche = uint256(now - crowdTokenSaleEndTime) / (3 * 30 days);

        if (teamTranchesReleased < maxTeamTranches && currentTranche > teamTranchesReleased) {
            teamTranchesReleased++;
            uint256 amount = safeMul(taloTeamAlloc, 125); // 12.5% of allocation for TALO team
            balanceOf[taloTeamAddress] = safeAdd(balanceOf[taloTeamAddress], amount);
            emit Transfer(0x0, taloTeamAddress, amount);
            totalAllocated = safeAdd(totalAllocated, amount);
            totalAllocatedToTeam = safeAdd(totalAllocatedToTeam, amount);
            return true;
        }
        revert();
    }

    /**
        @dev release Advisors Token allocation. The left amount of token will be transfered to TALO Foundation

        @return true if successful, throws if not
    */
    function releaseTALOAdvisorTokens() sixMonthTimeLock ownerOnly public returns(bool success) {
        require(totalAllocatedToAdvisors == 0);
        for (uint256 i = 0; i < advisorAddresses.length; ++i) {
            address advisorAddress = advisorAddresses[i];
            uint256 advisorAllocation = advisorAllocations[i];
            balanceOf[advisorAddress] = safeAdd(balanceOf[advisorAddress], advisorAllocation);
            totalAllocatedToAdvisors = safeAdd(totalAllocatedToAdvisors, advisorAllocation);
            emit Transfer(0x0, advisorAddress, advisorAllocation);
        }
        
        // Transfer the left amount of token to TALO Foundation
        uint256 amount = safeSub(taloAdvisorAllocation, totalAllocatedToAdvisors);
        if (amount > 0) {
            totalAllocatedToFoundation = safeAdd(totalAllocatedToFoundation, amount);
            balanceOf[taloFoundationAddress] = safeAdd(balanceOf[taloFoundationAddress], amount);
            emit Transfer(0x0, taloFoundationAddress, amount);
        }
        
        totalAllocated = safeAdd(totalAllocated, taloAdvisorAllocation);
        return true;
    }
    
    /**
        @dev release TALO Foundation 5% Token pre-allocation. 
        Owner can call this function anytime to get the 5%.

        @return true if successful, throws if not
    */
    function releasePreTALOFoundationTokens() ownerOnly public returns(bool success) {
        require(totalPreAllocatedToFoundation == 0);
        
        uint256 amount = taloFoundationPreAllocation;
        balanceOf[taloFoundationAddress] = safeAdd(balanceOf[taloFoundationAddress], amount);
        emit Transfer(0x0, taloFoundationAddress, amount);
        totalAllocated = safeAdd(totalAllocated, amount);
        totalPreAllocatedToFoundation = safeAdd(totalPreAllocatedToFoundation, amount);
        return true;
    }
    
     /**
        @dev release TALO Foundation Token allocation
        All token left from the public sale will also be send back to the Foundation

        @return true if successful, throws if not
    */
    function releaseTALOFoundationTokens() afterCrowdTokenSale ownerOnly public returns(bool success) {
        require(totalAllocatedToFoundation == 0);
        require(totalPreAllocatedToFoundation > 0); // Already release the pre-allocation for TALO Foundation first
        
        // Collect the unsold token from the Crowd Token Sale
        uint256 amountOfTokensLeft = balanceOf[taloCrowdTokenSaleAddress];
        balanceOf[taloCrowdTokenSaleAddress] = 0;
        
        uint256 amount = safeAdd(taloFoundationAllocation, amountOfTokensLeft);
        
        // Substract the bonus part
        amount = safeSub(amount, totalAllocatedForBonus);
        
        balanceOf[taloFoundationAddress] = safeAdd(balanceOf[taloFoundationAddress], amount);
        emit Transfer(0x0, taloFoundationAddress, amount);
        totalAllocated = safeAdd(totalAllocated, amount);
        totalAllocatedToFoundation = safeAdd(totalAllocatedToFoundation, amount);
        // Count the 5% token pre-allocated to foundation
        totalAllocatedToFoundation = safeAdd(totalAllocatedToFoundation, totalPreAllocatedToFoundation);
        return true;
    }

    /**
        @dev Keep track of token allocations for crowd token sale
        can only be called by the crowdfund contract
    */
    function addToAllocation(uint256 _amount) crowdTokenSaleContractOnly public {
        totalAllocated = safeAdd(totalAllocated, _amount);
    }
    
    /**
     * @dev Send bonus to investors during the crowd token sale
     */
    function transferBonusToken(address _contributorAddress, uint256 _bonusAmount) crowdTokenSaleContractOnly validAddress(_contributorAddress) public {
        // This contributor should have already bought some tokens
        require(balanceOf[_contributorAddress] > 0);
        uint256 totalAllocatedForBonusAmount = safeAdd(totalAllocatedForBonus, _bonusAmount);
        require(totalAllocatedForBonusAmount <= maximumBonusAllocation);
        
        balanceOf[_contributorAddress] = safeAdd(balanceOf[_contributorAddress], _bonusAmount);
        emit Transfer(0x0, _contributorAddress, _bonusAmount);
        totalAllocated = safeAdd(totalAllocated, _bonusAmount);
        totalAllocatedForBonus = totalAllocatedForBonusAmount;
    }

    /**
        @dev Function to allow early transfers for all accounts
        can only be called by the owner of the contract
    */
    function allowEarlyTransfers() ownerOnly public {
        isEarlyTransferringAllowed = true;
    }
    
    /**
        @dev Function to release token to all public
        can only be called by the owner of the contract
    */
    function releaseTokenToPublic() sixMonthTimeLock ownerOnly public {
        isReleasedToPublic = true;
    }

    /**
        @dev User transfers are allowed/rejected
        Transfers are forbidden before the end of the crowdfund
    */
    function isTransferAllowed() internal constant returns(bool) {
        if (now > crowdTokenSaleEndTime || isEarlyTransferringAllowed == true) {
            return true;
        }
        return false;
    }
}

contract TALOCrowdTokenSale is TokenHolder, Whitelist {
    uint256 constant public TALO_UNIT = 10 ** 18;

    ///////////////////////////////////////// VARIABLE INITIALIZATION /////////////////////////////////////////

    uint256 constant public startTime = 1527465600;     // 05/28/2018 @ 12:00am (UTC)
    uint256 constant public endTime = 1538351999;       // 09/30/2018 @ 11:59pm (UTC)
    address public beneficiary = 0x0;                   // address to receive all ether contributions
    address public tokenAddress = 0x0;                  // address of the token itself
    uint256 public conversionRate = 12000;              // conversionRate from ETHER to TALO
    
    // Bonus const
    uint256[] internal bonusTokenRanges = [40 * 10**6 * TALO_UNIT, 100 * 10**6 * TALO_UNIT, 180 * 10**6 * TALO_UNIT, 280 * 10**6 * TALO_UNIT, 400 * 10**6 * TALO_UNIT];
    uint256[] internal bonusTokenRangePercents = [35, 30, 25, 20, 10];

    uint256 constant internal bonusTokenBulk1 = 20 * 10**6 * TALO_UNIT;
    uint256 constant internal bonusTokenBulk2 = 10 * 10**6 * TALO_UNIT;
    uint256 constant internal bonusTokenBulk3 = 5 * 10**6 * TALO_UNIT;
    uint256 constant internal bonusTokenBulk1Percent = 15;
    uint256 constant internal bonusTokenBulk2Percent = 10;
    uint256 constant internal bonusTokenBulk3Percent = 5;
    
    // TALO Token interface
    TALOToken token;                                     

    ///////////////////////////////////////// EVENTS /////////////////////////////////////////

    event CrowdTokenSaleContribution(address indexed _contributor, uint256 _amount, uint256 _currentTotalTAlOSold, uint256 _return, uint256 _bonusReturn);

    ///////////////////////////////////////// CONSTRUCTOR /////////////////////////////////////////

    /**
        @dev constructor
        @param _beneficiary Address that will be receiving the ETH contributed
    */
    function TALOCrowdTokenSale(address _beneficiary) validAddress(_beneficiary) public
    {
        beneficiary = _beneficiary;
    }

    ///////////////////////////////////////// MODIFIERS /////////////////////////////////////////

    // Ensures that the current time is between startTime (inclusive) and endTime (exclusive)
    modifier between() {
        assert(now >= startTime && now < endTime);
        _;
    }

    // Ensures the Token address is set
    modifier tokenIsSet() {
        require(tokenAddress != 0x0);
        _;
    }

    ///////////////////////////////////////// OWNER FUNCTIONS /////////////////////////////////////////

    /**
        @dev Sets the TALO Token address
        Can only be called once by the owner
        @param _tokenAddress TALO Token Address
    */
    function setToken(address _tokenAddress) validAddress(_tokenAddress) ownerOnly public {
        require(tokenAddress == 0x0);
        tokenAddress = _tokenAddress;
        token = TALOToken(_tokenAddress);
    }

    /**
        @dev Sets a new Beneficiary address
        Can only be called by the owner
        @param _newBeneficiary    Beneficiary Address
    */
    function changeBeneficiary(address _newBeneficiary) validAddress(_newBeneficiary) ownerOnly public {
        beneficiary = _newBeneficiary;
    }
    
    /**
        @dev Update the conversion rate
        TALO Foundation use this function to update the conversionRate to make the TALO's price fit with the ETHER's price

        @return true if successful, throws if not
    */
    function updateConversionRate(uint256 _conversionRate) ownerOnly public returns (bool success) {
        require(_conversionRate > 0);
        conversionRate = _conversionRate;
        return true;
    }

    ///////////////////////////////////////// PUBLIC FUNCTIONS /////////////////////////////////////////
    /**
        @dev ETH contribution function
        Can only be called during the crowdsale. Also allows a person to buy tokens for another address

        @return tokens issued in return
    */
    function contributeETH(address _to) public validAddress(_to) between tokenIsSet validInvestor validInvestorAddress(_to) payable returns (uint256 amount) {
        return processContribution(_to);
    }
    
    /**
        @dev Get the current conversion rate

        @return the current conversionRate
    */
    function getConversionRate() view public returns (uint256 _conversionRate) {
        return conversionRate;
    }
    
    /**
        @dev handles contribution logic
        note that the Contribution event is triggered using the sender as the contributor, regardless of the actual contributor

        @return tokens issued in return
    */
    function processContribution(address _to) private returns (uint256 amount) {
        uint256 tokenAmount = getTotalAmountOfTokens(msg.value);
        uint256 totalTokenSold = totalTALOSold();
        require(safeAdd(tokenAmount, totalTokenSold) <= bonusTokenRanges[4]);
        
        // Transfer tokens
        beneficiary.transfer(msg.value);
        token.transfer(_to, tokenAmount);
        
        // Calculate the bonus
        uint256 tokenBonusAmount = getBonusAmountOfTokens(tokenAmount);
        
        // Add allocation
        token.addToAllocation(tokenAmount);
        
        // Transfer bonus
        token.transferBonusToken(_to, tokenBonusAmount);
        
        // Emit event
        emit CrowdTokenSaleContribution(_to, msg.value, totalTokenSold, tokenAmount, tokenBonusAmount);
        return tokenAmount;
    }


    ///////////////////////////////////////// CONSTANT FUNCTIONS /////////////////////////////////////////
    
    /**
        @dev Returns total tokens allocated so far
        Constant function that simply returns a number

        @return total tokens allocated so far
    */
    function totalTALOSold() public constant returns(uint256 total) {
        return token.totalAllocated();
    }
    
    /**
        @dev computes the number of tokens that should be issued for a given contribution
        @param _contribution    contribution amount (in wei)
        @return computed number of tokens (in 10^(18) TALO unit)
    */
    function getTotalAmountOfTokens(uint256 _contribution) public view returns (uint256 amountOfTokens) {
        return safeMul(_contribution, conversionRate);
    }
    
    /**
        @dev computes the bonus tokens should be received
        @return computed number of tokens (in 10^(18) TALO unit)
    */
    function getBonusAmountOfTokens(uint256 tokenAmount) public view returns (uint256 bonusAmountOfTokens) {
        uint256 tokenSold = totalTALOSold();
        uint256 i = 0;
        while (i < 5 && tokenSold >= bonusTokenRanges[i]) ++i;
        require(i < 5);
        
        uint256 bonusAmount = safeMul(tokenAmount / 100, getBonusPercentForBulk(tokenAmount));
        uint256 tokenAmountLeft = tokenAmount;
        while (i < 5) {
            if (safeAdd(tokenSold, tokenAmountLeft) <= bonusTokenRanges[i]) {
                bonusAmount = safeAdd(bonusAmount, safeMul(tokenAmountLeft / 100, bonusTokenRangePercents[i]));
                break;
            } else {
                uint256 subAmount = safeSub(bonusTokenRanges[i], tokenSold);
                bonusAmount = safeAdd(bonusAmount, safeMul(subAmount / 100, bonusTokenRangePercents[i]));
                tokenAmountLeft = safeSub(tokenAmountLeft, subAmount);
                ++i;
            }
        }
        return bonusAmount;
    }
    
    /**
        @dev get the bonus percent for bulk token buys
        @return return the percent for each bulk range
    */
    function getBonusPercentForBulk(uint256 tokenAmount) private pure returns (uint256 bonusAmountOfTokens) {
        if (tokenAmount >= bonusTokenBulk1) return bonusTokenBulk1Percent;
        else if (tokenAmount >= bonusTokenBulk2) return bonusTokenBulk2Percent;
        else if (tokenAmount >= bonusTokenBulk3) return bonusTokenBulk3Percent;
        return 0;
    }

    /**
        @dev Fallback function
        Main entry to buy into the crowdfund, all you need to do is send a value transaction
        to this contract address. Please include at least 100 000 gas in the transaction.
    */
    function() payable public validInvestor {
        contributeETH(msg.sender);
    }
}
