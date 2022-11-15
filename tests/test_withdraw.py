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

def test_withdraw_after_4_days_should_withdrawn_100_percents(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    chain.sleep(DAY * 4)

    distributor.withdraw({ "from": sender })

    assert token.balanceOf(sender, { "from": sender }) == 50 * 10e18

def test_withdraw_after_3_days_should_withdrawn_75_percents(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    chain.sleep(DAY * 3)

    distributor.withdraw({ "from": sender })

    assert token.balanceOf(sender, { "from": sender }) == 37.5 * 10e18

def test_withdraw_after_2_days_should_withdrawn_50_percents(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    chain.sleep(DAY * 2)

    distributor.withdraw({ "from": sender })

    assert token.balanceOf(sender, { "from": sender }) == 25 * 10e18

def test_withdraw_after_1_day_should_withdrawn_25_percents(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    chain.sleep(DAY * 1)

    distributor.withdraw({ "from": sender })

    assert token.balanceOf(sender, { "from": sender }) == 12.5 * 10e18

def test_withdraw_after_0_day_should_withdrawn_nothing(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    with reverts('There is nothing to widthdraw'):
        distributor.withdraw({ "from": sender })

def test_withdraw_twice_should_fail(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)
    distributor.participate({ "from": sender })

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    chain.sleep(DAY * 1)

    distributor.withdraw({ "from": sender })
    with reverts('Address has executed withdraw already'):
        distributor.withdraw({ "from": sender })

def test_withdraw_when_user_was_not_participated_should_fail(distributor, admin, token, deployer, sender):
    owner = deployer
    set_registration_round(distributor, admin)
    set_distribution_parameters(distributor, admin, token, owner)
    set_distribution_round(distributor, admin)
    deposit_tokens(distributor, token, owner)

    distributor.register({ "from": sender })
    chain.sleep(DAY)

    now = chain.time()

    unlocking_times = [now + DAY, now + DAY * 2, now + DAY * 3, now + DAY * 4];
    percents = [25, 25, 25, 25];

    distributor.setVestingParams(unlocking_times, percents, { "from": admin })
    distributor.setAddressDistributionAmount(sender, 50 * 10e18, { "from": admin })

    with reverts('Address is not participated in distribution'):
        distributor.withdraw({ "from": sender })