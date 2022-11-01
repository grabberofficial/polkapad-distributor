import time
from brownie import accounts, network, config, DistributorFactory

DEPLOYER = (0, "deployer_pk")

def set_registration_round(distributor, admin):
    today = time.time()
    tomorrow = today + 60 * 60 * 24

    distributor.setRegistrationRound(int(today), int(tomorrow), { "from": admin })

def deploy_factory(deployer):
    contract = DistributorFactory.deploy({ "from": deployer })

    return contract

def get_account(account):
    dev_index = account[0]
    private_key = account[1]

    if network.show_active() == "development":
        return accounts[dev_index]
    else:
        return accounts.add(config["addresses"][private_key])


def deploy(deployer):
    deploy_factory(deployer)


def main():
    deployer = get_account(DEPLOYER)
    deploy(deployer)
