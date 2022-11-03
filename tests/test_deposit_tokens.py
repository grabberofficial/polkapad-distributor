from brownie import chain, accounts, reverts, Distributor
from scripts.deploy import *

import pytest

@pytest.fixture
def distributor(factory, admin):
    factory.create({ "from": admin })
    address = factory.indexesToContracts(0)

    return Distributor.at(address)

@pytest.fixture
def token(deployer):
    return deploy_token(deployer)

@pytest.fixture
def factory(deployer):
    return deploy_factory(deployer)

@pytest.fixture
def deployer():
    return accounts[0]

@pytest.fixture
def admin():
    return accounts[1]

@pytest.fixture
def owner():
    return accounts[2]

@pytest.fixture
def sender():
    return accounts[3]

def test_deposit_tokens_should_deposited(distributor, token, admin, deployer):
    owner = deployer
    set_distribution_parameters(distributor, admin, token, owner)
    deposit_tokens(distributor, token, owner)

    is_deposited = distributor.distribution()[3]

    assert is_deposited is True

def test_deposit_tokens_as_no_owner_should_failed(distributor, sender):
    with reverts('Allows distribution owner address only'):
        distributor.depositTokens({ "from": sender })
   