// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import './Distributor.sol';

contract DistributorFactory {

    Distributor public distributorContract;

    mapping (uint => Distributor) public indexesToContracts;
    uint private _index;

    function create() public returns (Distributor) {
        distributorContract = new Distributor(msg.sender);

        indexesToContracts[_index] = distributorContract;
        _index++;

        return distributorContract;
    }
}