import os
import re
from datetime import datetime

# variables
date = datetime.now().strftime("%d-%m-%y_%H-%M-%S")
ShortTokens = sorted(['USDC', 'DAI', 'LINK', 'WETH', 'wBTC', 'MATIC', 'USDT', 'CRV', 'SUSHI', 'GHST', 'BAL', 'DPI', 'EURS', 'jEUR', 'agEUR', 'miMATIC']) # no AAVE, MaticX, stMATIC, or WMATIC
CollateralTokens = sorted(['USDC', 'DAI', 'LINK', 'WETH', 'wBTC', 'MATIC', 'USDT', 'CRV', 'SUSHI', 'GHST', 'BAL', 'DPI', 'EURS', 'jEUR', 'agEUR', 'AAVE', 'WMATIC', 'MaticX', 'miMATIC', 'stMATIC'])
outcomes = ['EvmError: Revert', 'EvmError: FatalExternalError', 'Arithmetic over/underflow', 'Log != expected log', 'SPL', 'PASS']
masterDict = dict((()))
numIterations = 0
userInput = 'N/A'
# configureables
dir  = 'shortLogs'
rpcURL = ['https://matic-mainnet.chainstacklabs.com', 'https://matic-mainnet.chainstacklabs.com'][0]


# init dict
for short in ShortTokens:
    masterDict[short] = dict()
    for collateral in CollateralTokens:
        masterDict[short][collateral] = dict()
        for outcome in outcomes:
            masterDict[short][collateral][outcome] = 0

# generate logs
print("Do you want to generate 1 new test result? Entering 'no' will direct the program to analysis without new test result")
while userInput != 'yes' and userInput != 'no':
    userInput = input("Enter 'yes' or 'no': ")
if userInput == 'yes':
    print("Generating test. This may take a minute or two...")
    os.system("forge test --optimize --fork-url " + rpcURL + " -vvv --match-contract ChildShortTest > "+ dir + "/" + date + ".txt")

# data scrape logs
for file in os.listdir (dir):
    numIterations += 1
    with open(dir + "/" + file) as f:
        for line in f:
            line = line.strip("\n")
            # lines we don't care about reading
            if re.match('^Test result:', line):
                break
            # lines we care about reading
            if '[FAIL' in line or '[PASS' in line:
                result = re.search(r'([A-Z]{4}){1}', line).group()
                shortToken = re.search('(?<=test_short_all_).*(?=_using)', line).group()
                baseToken = re.search('(?<=using_).*(?=\(uint256)', line).group()

                # extract PASS or error message
                if result == 'PASS':
                    masterDict[shortToken][baseToken][result] += 1
                else:
                    failError = re.search('(?<=Reason:\s).*(?=\sCounterexample)', line).group()
                    masterDict[shortToken][baseToken][failError] += 1

# analyze
print("\033[0;32mStable pairs that PASS all " + str(numIterations) + " iterations of tests\033[00m:")
for short in ShortTokens:
    for collateral in CollateralTokens:
        if masterDict[short][collateral]['PASS'] == numIterations:
            print("shortToken: ",short, "\tbaseToken: ", collateral)

print("\n\033[0;31mPairs that FAIL any iterations of tests\033[00m:")
print("(Error message: #ofIterationsErrorManifested)\n")
for short in ShortTokens:
    for collateral in CollateralTokens:
        if masterDict[short][collateral]['PASS'] != numIterations:
            print("shortToken: ",short, "\tbaseToken: ", collateral)
            for outcome in outcomes:
                if masterDict[short][collateral][outcome] != 0:
                    if outcome != 'PASS':
                        print("\033[0;31m" + outcome + "\033[00m" + ": " + str(masterDict[short][collateral][outcome]))
                    elif outcome == 'PASS':
                        print("\033[0;32m" + outcome + "\033[00m" + ": " + str(masterDict[short][collateral][outcome]))
    print("\n")

print("""Analysis of {var1} iterations of v1-core/test/test_child/Child.short.t.sol complete. 
View the v1-core/{var2} directory for more details about the tests.\n""".format(var1=numIterations, var2=dir))