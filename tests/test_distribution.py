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

def test_set_distribution_parameters_should_set(distributor, admin, token, owner):
    set_distribution_parameters(distributor, admin, token, owner)

    is_created = distributor.distribution()[2]

    assert is_created is True

def test_set_distribution_parameters_as_not_admin_should_fail(distributor, sender, token, owner):
    with reverts('Allows admin address only'):
        set_distribution_parameters(distributor, sender, token, owner)

def test_set_distribution_parameters_twice_should_fail(distributor, admin, token, owner):
    set_distribution_parameters(distributor, admin, token, owner)
    with reverts('Distribution already created'):
        set_distribution_parameters(distributor, admin, token, owner)

def test_set_distribution_round_should_set(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    distribution_round_startdate = distributor.distributionRound()[0]
    distribution_round_enddate = distributor.distributionRound()[1]

    chain.sleep(60 * 60 * 48)

    distribution_round_not_over = chain.time() > distribution_round_startdate and chain.time() < distribution_round_enddate

    assert distribution_round_not_over is True

def test_set_distribution_round_as_not_admin_should_fail(distributor, admin, sender, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)

    with reverts('Allows admin address only'):
        set_distribution_round(distributor, sender)

def test_set_distribution_round_before_parameters_should_fail(distributor, admin):
    set_registration_round(distributor, admin)

    with reverts('Distribution parameters are not set'):
        set_distribution_round(distributor, admin)

def test_participate_should_participated(distributor, admin, sender, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(60 * 60 * 48)

    distributor.participate({ "from": sender })

    is_participated = distributor.participations(sender)[1]

    assert is_participated is True

def test_participate_twice_should_faield(distributor, admin, sender, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(60 * 60 * 48)

    distributor.participate({ "from": sender })
    with reverts('Address already participated'):
        distributor.participate({ "from": sender })