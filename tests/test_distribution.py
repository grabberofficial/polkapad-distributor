from brownie import accounts, reverts, Distributor
from brownie.exceptions import VirtualMachineError
from scripts.deploy import *

import pytest
import time

@pytest.fixture
def distributor(factory, admin):
    factory.create({ "from": admin })
    address = factory.indexesToContracts(0)

    return Distributor.at(address)

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
def sender():
    return accounts[2]

def test_set_registration_round_should_set(distributor, admin):
    set_registration_round(distributor, admin)
    
    registration_round_startdate = distributor.registrationRound()[0]
    registration_round_enddate = distributor.registrationRound()[1]
    registration_round_stopped = distributor.registrationRound()[2]

    registration_round_not_over = time.time() > registration_round_startdate and time.time() < registration_round_enddate and registration_round_stopped is False

    assert registration_round_not_over is True

def test_set_registration_round_as_not_admin_should_fail(distributor, sender):
    with pytest.raises(VirtualMachineError):
        set_registration_round(distributor, sender)

def test_register_should_registered(distributor, admin, sender):
    set_registration_round(distributor, admin)

    distributor.register({ "from": sender })

    registration = distributor.registrations(sender)
    is_registered = registration[2]

    assert is_registered is True

def test_register_twice_should_fail(distributor, admin, sender):
    set_registration_round(distributor, admin)

    distributor.register({ "from": sender })
    with reverts('Address already registered'):
        distributor.register({ "from": sender })


def test_register_when_round_is_over_should_fail(distributor, admin, sender):
    set_registration_round(distributor, admin)

    transaction = distributor.register({ "from": sender })

    assert transaction.revert_msg == 'Registration round is over'