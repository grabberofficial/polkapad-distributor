// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract Distributor {
    using SafeMath  for uint256;
    using SafeERC20 for IERC20;

    struct Distribution {
        IERC20      token;
        address     owner;

        bool        isCreated;
        bool        tokensDeposited;

        uint256     amountOfTokensToDistribute;
        uint256     totalTokensDistributed;
    }

    struct Registration {
        uint256     datetime;
        uint256     distributionAmount;
        bool        isRegistered;
    }

    struct Participation {
        uint256     datetime;
        bool        isParticipated;
    }

    struct RegistrationRound {
        uint256             startDate;
        uint256             endDate;
        bool                isStopped;
    }

    struct DistributionRound {
        uint256             startDate;
        uint256             endDate;
    }

    struct Allocation {
        address             user;
        uint256             amount;
    }

    mapping (uint256 => address)        public indexToClaimedUsers;
    uint256                             public claimedUsersCount;

    mapping (address => Registration)   public registrations;
    mapping (uint256 => address)        public indexToRegistrations;
    uint256                             public registrationsCount;

    mapping (address => Participation)  public participations;
    mapping (uint256 => address)        public indexToParticipiants;
    uint256                             public participiantsCount;

    mapping (address => uint)           public addressToEvent;
    mapping (address => bool)           public addressToWithdraw;

    uint256             public registrationFee;
    uint256             public totalRegistrationFee;
    bool                public registrationFeeWithdrawn;

    uint256             public vestingEndDate;
    uint256             public vestingPrecision;
    uint256             public vestingEventsCount;
    uint256[]           public vestingPortionsUnlockTime;
    uint256[]           public vestingPercentPerPortion;

    address             public admin;

    Distribution        public distribution;
    RegistrationRound   public registrationRound;
    DistributionRound   public distributionRound;

    bool                public leftoverWithdrawn;

    event Participated(address indexed account, uint256 timestamp);
    event Registered(address indexed account, uint256 timestamp);
    event MultipleRegistrationCompleted(uint256 timestamp);
    event MultipleParticipationCompleted(uint256 timestamp);
    event DistributionRoundSet(uint256 timestamp);
    event RegistrationRoundSet(uint256 timestamp);
    event RegistrationRoundStopped(uint256 timestamp);
    event TokensWithdrawn(address indexed account, uint256 amount);
    event VestingParametersSet(uint256 timestamp);
    event AllocationsSet(uint256 timestamp);

    constructor(address _admin) {
        admin = _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Allows admin address only');
        _;
    }

    modifier onlyDistributionOwner() {
        require(msg.sender == distribution.owner, 'Allows distribution owner address only');
        _;
    }

    modifier onlyIfRegistrationIsNotOver() {
        require(
            block.timestamp >= registrationRound.startDate && 
            block.timestamp <= registrationRound.endDate && 
            !registrationRound.isStopped,
            'Registration round is over or not started yet');
        _;
    }

    modifier onlyIfDistributionIsNotOver() {
        require(
            block.timestamp >= distributionRound.startDate &&
            block.timestamp <= distributionRound.endDate,
            'Distribution round is over or not started yet');
        _;
    }

    function register() public payable onlyIfRegistrationIsNotOver {
        require(registrationFee > 0, 'Registration fee is not set');
        require(msg.value == registrationFee, 'Registration fee amount issue');
        totalRegistrationFee += msg.value;

        _registerUser(msg.sender);
    }

    function registerUser(address _address) public onlyIfRegistrationIsNotOver onlyAdmin {
        _registerUser(_address);
    }

    function registerMultipleUsers(address[] memory _addresses) public onlyIfRegistrationIsNotOver onlyAdmin {
        require(_addresses.length > 0, 'The addresses array must contain one element at least');

        for (uint i = 0; i < _addresses.length; i++) {
            if (!registrations[_addresses[i]].isRegistered) {
                _registerUser(_addresses[i]);
            }
        }

        emit MultipleRegistrationCompleted(block.timestamp);
    }

    function participate() public onlyIfDistributionIsNotOver {
        _participate(msg.sender);
    }

    function participateMultipleUsers(address[] memory _addresses) public onlyIfDistributionIsNotOver onlyAdmin {
        require(_addresses.length > 0, 'The addresses array must contain one element at least');

        for (uint i = 0; i < _addresses.length; i++) {
            if (!participations[_addresses[i]].isParticipated) {
                _participate(_addresses[i]);
            }
        }

        emit MultipleParticipationCompleted(block.timestamp);
    }

    function withdraw() public {
        require(
            vestingPercentPerPortion.length > 0 &&
            vestingPortionsUnlockTime.length > 0,
            'Vesting parameters are not set'
        );
        require(registrations[msg.sender].isRegistered, 'Address is not registered');
        require(participations[msg.sender].isParticipated, 'Address is not participated in distribution');
        require(!addressToWithdraw[msg.sender], 'Address has executed withdraw already');

        uint256 totalToWithdraw = 0;
        Registration storage registration = registrations[msg.sender];

        require(registration.distributionAmount > 0, 'There is nothing to withdraw');

        for (uint i = 0; i < vestingPortionsUnlockTime.length; i++) {
            if (block.timestamp >= vestingPortionsUnlockTime[i]) {
                 uint256 amountWithdrawing = registration
                    .distributionAmount
                    .mul(vestingPercentPerPortion[i])
                    .div(vestingPrecision);

                totalToWithdraw = totalToWithdraw.add(amountWithdrawing);
            }
        }

        require(totalToWithdraw > 0, 'There is nothing to widthdraw');
        
        indexToClaimedUsers[claimedUsersCount] = msg.sender;
        
        addressToWithdraw[msg.sender] = true;
        distribution.totalTokensDistributed = distribution.totalTokensDistributed.add(totalToWithdraw);

        distribution.token.safeTransfer(msg.sender, totalToWithdraw);
        
        emit TokensWithdrawn(msg.sender, totalToWithdraw);
    }

    function withdrawEvent() public {
        require(vestingEventsCount > 0, 'Vesting parameters are not set');
        require(!addressToWithdraw[msg.sender], 'Address already widthdrawn');

        uint256 totalToWithdraw = 0;
        Registration storage registration = registrations[msg.sender];

        require(registration.distributionAmount > 0, 'There is nothing to withdraw');
        
        uint addressEvent = addressToEvent[msg.sender];
        for (uint i = 0; i < addressEvent; i++) {
            uint256 amountWithdrawing = registration
                .distributionAmount
                .mul(vestingPercentPerPortion[i])
                .div(vestingPrecision);

            registration.distributionAmount = registration.distributionAmount.sub(amountWithdrawing);
            totalToWithdraw = totalToWithdraw.add(amountWithdrawing);
        }

        require(totalToWithdraw > 0, 'There is nothing to widthdraw');

        addressToWithdraw[msg.sender] = true;
        distribution.totalTokensDistributed = distribution.totalTokensDistributed.add(totalToWithdraw);

        distribution.token.safeTransfer(msg.sender, totalToWithdraw);
        
        emit TokensWithdrawn(msg.sender, totalToWithdraw);
    }

    function setEventVestingParams(
        uint256 _eventsCount,
        uint256[] memory _percents
    ) public onlyAdmin {
        require(_eventsCount == _percents.length, 'Events could must be equal with Percept Per Portion length');
        require(distribution.isCreated, 'Distribution is not created');

        vestingEventsCount = _eventsCount;

        uint256 precision = 0;
        for (uint256 i = 0; i < _eventsCount; i++) {
            vestingPercentPerPortion.push(_percents[i]);
            precision = precision.add(_percents[i]);
        }

        require(vestingPrecision == precision, 'Precision percents issue');

        emit VestingParametersSet(block.timestamp);
    }

    function setVestingParams(
        uint256[] memory _unlockingTimes,
        uint256[] memory _percents
    ) public onlyAdmin {
        require(
            vestingPercentPerPortion.length == 0 &&
            vestingPortionsUnlockTime.length == 0,
            'Vesting parameters already set'
        );
        require(_unlockingTimes.length == _percents.length, 'Unlocking Times length must be equal with Percent Per Portion length');
        require(distribution.isCreated, 'Distribution is not created');
        require(_unlockingTimes[0] > distributionRound.endDate, 'Unlock time must be after the distribution ends');

        uint256 precision = 0;
        for (uint256 i = 0; i < _unlockingTimes.length; i++) {
            if (i > 0) {
                require(_unlockingTimes[i] > _unlockingTimes[i - 1], 'Unlock time must be greater than previous');
            }

            vestingPortionsUnlockTime.push(_unlockingTimes[i]);
            vestingPercentPerPortion.push(_percents[i]);

            precision = precision.add(_percents[i]);
        }
        
        require(vestingPrecision == precision, 'Precision percents issue');

        emit VestingParametersSet(block.timestamp);
    }

    function setMultipleAddressDistributionAmount(Allocation[] memory _allocations) public onlyAdmin {
        require(_allocations.length > 0, 'The allocation array must contain one element at least');

        for (uint i = 0; i < _allocations.length; i++) {
            Allocation memory allocation = _allocations[i];
            require(registrations[allocation.user].isRegistered, 'Provided address is not registered');

            registrations[allocation.user].distributionAmount = allocation.amount;
        }

        emit AllocationsSet(block.timestamp);
    }

    function setAddressDistributionAmount(address _address, uint256 _amount) public onlyAdmin {
        require(registrations[_address].isRegistered, 'Provided address is not registered');

        registrations[_address].distributionAmount = _amount;
    }

    function setDistributionParameters(
        uint256 _amountOfTokensToDistribute,
        uint256 _vestingPrecision,
        address _owner,
        address _token
    ) public onlyAdmin {
        require(!distribution.isCreated, 'Distribution already created');

        distribution.token = IERC20(_token);
        distribution.owner = _owner;
        distribution.amountOfTokensToDistribute = _amountOfTokensToDistribute;

        vestingPrecision = _vestingPrecision;

        distribution.isCreated = true;
    }

    function setRegistrationRound(uint256 _startDate, uint256 _endDate) public onlyAdmin {
        require(
            _startDate >= block.timestamp &&
            _endDate > _startDate
        );

        registrationRound.startDate = _startDate;
        registrationRound.endDate = _endDate;

        emit RegistrationRoundSet(block.timestamp);
    }

    function setDistributionRound(uint256 _startDate, uint256 _endDate) public onlyAdmin {
        require(distribution.isCreated, 'Distribution parameters are not set');
        require(_startDate > registrationRound.endDate, 'Distribution round must be later than registration round');

        distributionRound = DistributionRound({
            startDate: _startDate,
            endDate: _endDate
        });

        emit DistributionRoundSet(block.timestamp);
    }

    function setVestingEndDate(uint256 _endDate) public onlyAdmin {
        require(
            vestingPercentPerPortion.length > 0 &&
            vestingPortionsUnlockTime.length > 0,
            'Vesting parameters are not set'
        );
        require(
            _endDate > vestingPortionsUnlockTime[vestingPortionsUnlockTime.length - 1],
            'The last day of the distribution must be later than the last unlock time'
        );

        vestingEndDate = _endDate;
    }

    function getRegisteredUsers() public view returns (address[] memory) {
        address[] memory addresses = new address[](registrationsCount);

        for (uint i = 0; i < registrationsCount; i++) {
            address registrationAddress = indexToRegistrations[i];
            addresses[i] = registrationAddress;
        }

        return addresses;
    }

    function getParticipatedUsers() public view returns (address[] memory) {
        address[] memory addresses = new address[](participiantsCount);

        for (uint i = 0; i < participiantsCount; i++) {
            address participiantsAddress = indexToParticipiants[i];
            addresses[i] = participiantsAddress;
        }

        return addresses;
    }

    function getClaimedUsers() public view returns (address[] memory) {
        address[] memory addresses = new address[](claimedUsersCount);

        for (uint i = 0; i < claimedUsersCount; i++) {
            address claimedUserAddress = indexToClaimedUsers[i];
            addresses[i] = claimedUserAddress;
        }

        return addresses;
    }

    function getVestingPortions() public view returns (uint256[] memory) {
        return vestingPercentPerPortion;
    }
    function getVestingUnlocks() public view returns (uint256[] memory) {
        return vestingPortionsUnlockTime;
    }

    function stopRegistrationRound() public onlyAdmin {
        registrationRound.isStopped = true;

        emit RegistrationRoundStopped(block.timestamp);
    }

    function setAddressEvent(address _address, uint _event) public onlyDistributionOwner {
       addressToEvent[_address] = _event;
    }

    function setRegistrationFee(uint256 _feeAmount) public onlyAdmin {
        require(
            block.timestamp < registrationRound.startDate, 
            'Set registration fee is not possible while registration round is running');

        registrationFee = _feeAmount;   
    }

    function depositTokens() public onlyDistributionOwner {
        require(distribution.isCreated, 'Distribution is not created');
        require(!distribution.tokensDeposited, 'Tokens has been deposited already');

        distribution.tokensDeposited = true;

        distribution.token.safeTransferFrom(
            msg.sender,
            address(this),
            distribution.amountOfTokensToDistribute
        );
    }

    function withdrawLeftover() public onlyAdmin {
        require(vestingEndDate > 0, 'Vesting end date is not set');
        require(block.timestamp >= vestingEndDate, 'Vesting period is not finished yet');
        require(!leftoverWithdrawn, 'Leftover already withdrawn');

        uint256 leftover = distribution.amountOfTokensToDistribute.sub(distribution.totalTokensDistributed);
        require(leftover > 0, 'There is nothing to withdraw');
        
        leftoverWithdrawn = true;
        
        distribution.token.safeTransfer(msg.sender, leftover);
    }

    function withdrawFee() public onlyAdmin {
        require(block.timestamp >= registrationRound.endDate, 'Registration round is not finished yet');
        require(!registrationFeeWithdrawn, 'Registration fee already withdrawn');
        require(totalRegistrationFee > 0, 'There is nothing to withdraw');
        
        registrationFeeWithdrawn = true;
        
        payable(msg.sender).transfer(totalRegistrationFee);
    }

    function _registerUser(address _address) private {
        require(!registrations[_address].isRegistered, 'Address already registered');
        
        registrations[_address] = Registration(block.timestamp, 0, true);
        indexToRegistrations[registrationsCount] = _address;
        registrationsCount++;

        emit Registered(_address, block.timestamp);
    }

    function _participate(address _address) private {
        require(!participations[_address].isParticipated, 'Address already participated');
        
        participations[_address] = Participation(block.timestamp, true);
        indexToParticipiants[participiantsCount] = _address;
        participiantsCount++;

        emit Participated(_address, block.timestamp);
    }
}
