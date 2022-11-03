// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract Distributor {
    using SafeMath for uint256;
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

    mapping (address => Registration)   public registrations;
    mapping (address => Participation)  public participations;
    mapping (address => uint)           public addressToEvent;
    mapping (address => bool)           public addressToWithdraw;

    bool                public distrubutionParametersSet;

    uint256             public vestingPrecision;
    uint256             public vestingEventsCount;
    uint256[]           public vestingPortionsUnlockTime;
    uint256[]           public vestingPercentPerPortion;

    address             public admin;
    Distribution        public distribution;
    RegistrationRound   public registrationRound;
    DistributionRound   public distributionRound;

    event Participated(address indexed account, uint256 timestamp);
    event Registered(address indexed account, uint256 timestamp);
    event DistributionRoundSet(uint256 timestamp);
    event RegistrationRoundSet(uint256 timestamp);
    event RegistrationRoundStopped(uint256 timestamp);
    event TokensWithdrawn(address indexed account, uint256 amount);
    event VestingParametersSet(uint256 timestamp);

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
            block.timestamp < registrationRound.endDate && 
            block.timestamp >= registrationRound.startDate && 
            !registrationRound.isStopped,
            'Registration round is over');
        _;
    }

    modifier onlyIfDistributionIsNotOver() {
        require(
            block.timestamp < distributionRound.endDate &&
            block.timestamp >= distributionRound.startDate,
            'Distribution round is over');
        _;
    }

    function register() public onlyIfRegistrationIsNotOver {
        require(!registrations[msg.sender].isRegistered, 'Address already registered');
        
        registrations[msg.sender] = Registration(block.timestamp, 0, true);

        emit Registered(msg.sender, block.timestamp);
    }

    function participate() public onlyIfDistributionIsNotOver {
        require(!participations[msg.sender].isParticipated, 'Address already participated');
        
        participations[msg.sender] = Participation(block.timestamp, true);

        emit Participated(msg.sender, block.timestamp);
    }

    function withdraw() public {
        require(
            vestingPercentPerPortion.length > 0 &&
            vestingPortionsUnlockTime.length > 0,
            'Vesting parameters already set'
        );
        require(participations[msg.sender].isParticipated, 'Address is not participated in distribution');
        require(addressToWithdraw[msg.sender], 'Address already widthdrawn');

        uint256 totalToWithdraw = 0;
        Registration storage registration = registrations[msg.sender];

        require(registration.distributionAmount > 0, 'There is nothing to withdraw');

        for (uint i = 0; i < vestingPortionsUnlockTime.length; i++) {
            if (block.timestamp >= vestingPortionsUnlockTime[i]) {
                 uint256 amountWithdrawing = registration
                    .distributionAmount
                    .mul(vestingPercentPerPortion[i])
                    .div(vestingPrecision);

                registration.distributionAmount = registration.distributionAmount.sub(amountWithdrawing);
                totalToWithdraw = totalToWithdraw.add(amountWithdrawing);
            }
        }

        addressToWithdraw[msg.sender] = true;

        require(totalToWithdraw > 0, 'There is nothing to widthdraw');
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

        addressToWithdraw[msg.sender] = true;

        require(totalToWithdraw > 0, 'There is nothing to widthdraw');
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
        registrationRound = RegistrationRound({
            startDate: _startDate,
            endDate: _endDate,
            isStopped: false
        });

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

    function stopRegistrationRound() public onlyAdmin {
        registrationRound.isStopped = true;

        emit RegistrationRoundStopped(block.timestamp);
    }

    function setAddressEvent(address _address, uint _event) public onlyDistributionOwner {
       addressToEvent[_address] = _event;
    }

    function depositTokens() public onlyDistributionOwner {
        require(!distribution.tokensDeposited, 'Tokens has been deposited already');

        distribution.tokensDeposited = true;

        distribution.token.safeTransferFrom(
            msg.sender,
            address(this),
            distribution.amountOfTokensToDistribute
        );
    }
}
