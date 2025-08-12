import MetaTrader5 as mt5
result=mt5.initialize()
accountinfo=mt5.account_info()
#print(accountinfo)
#get balance
balance=mt5.account_info().balance
print("Balance: ",balance)
login=mt5.account_info().login
print("login: ",login)
#using array method
loginnew=mt5.account_info()[0]
print("login: ",loginnew)