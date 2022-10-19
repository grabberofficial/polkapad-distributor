from brownie import accounts, config
from brownie.exceptions import VirtualMachineError
from scripts.deploy import *

import pytest

@pytest.fixture
def sale(deployer):
    return deploy_factory(deployer)

@pytest.fixture
def deployer():
    return accounts[0]

@pytest.fixture
def sender():
    return accounts[1]

def test_register_user_should_register(sale, sender):
    sale.register({ "from": sender })

    # dot_account = accounts.at(config["addresses"]["dot_owner"], force=True)

    registration = sale.registrations(sender)

    actual_value = registration.isRegistered
    expected_value = True

    assert actual_value == expected_value