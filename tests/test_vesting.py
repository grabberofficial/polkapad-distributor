import pytest
from brownie import Distributor, accounts, chain, reverts

from scripts.deploy import *

DAY = 60 * 60 * 48

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

def test_set_classic_vesting_parameters_should_set(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [250, 250, 250, 250];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })

    assert distributor.vestingPortionsUnlockTime(0) > 0

def test_set_classic_vesting_parameters_as_not_admin_should_fail(distributor, admin, token, owner, sender):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    with reverts('Allows admin address only'):
        distributor.setVestingParams(unlocking_times, percents, { "from": sender })

def test_set_classic_vesting_parameters_with_incorrect_dates_should_fail(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 3, now + DAY * 2, now + DAY * 4];
    percents = [25, 25, 25, 25];

    with reverts('Unlock time must be greater than previous'):
        distributor.setVestingParams(unlocking_times, percents, { "from": admin })

def test_set_classic_vesting_parameters_with_incorrect_arrays_should_fail(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25];

    with reverts('Unlocking Times length must be equal with Percent Per Portion length'):
        distributor.setVestingParams(unlocking_times, percents, { "from": admin })

def test_set_classic_vesting_parameters_when_salen_is_not_created_should_fail(distributor, admin):
    set_registration_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    with reverts('Distribution is not created'):
        distributor.setVestingParams(unlocking_times, percents, { "from": admin })

def test_set_classic_vesting_parameters_with_incorrect_persents_should_fail(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 24];

    with reverts('Precision percents issue'):
        distributor.setVestingParams(unlocking_times, percents, { "from": admin })

def test_set_classic_vesting_parameters_when_vesting_already_set_should_fail(distributor, admin, token, owner):
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)

    chain.sleep(DAY * 2)
    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    with reverts('Vesting parameters already set'):
        distributor.setVestingParams(unlocking_times, percents, { "from": admin })
