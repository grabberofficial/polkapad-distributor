from brownie import accounts, config
from brownie.exceptions import VirtualMachineError
from scripts.deploy import *

import pytest

@pytest.fixture
def factory(deployer):
    return deploy_factory(deployer)

@pytest.fixture
def deployer():
    return accounts[0]

@pytest.fixture
def sender():
    return accounts[1]

def test_factory_create_should_created(factory, sender):
    factory.create({ "from": sender })
    created_contract_index = 0

    address = factory.indexesToContracts(created_contract_index)

    assert address is not None 