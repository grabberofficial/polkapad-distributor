from brownie import config, Contract
import json

def get_contract_from_abi(path, name, address):
    with open(path, "r") as file:
        abi = json.load(file)
        return Contract.from_abi(name, config["addresses"][address], abi)