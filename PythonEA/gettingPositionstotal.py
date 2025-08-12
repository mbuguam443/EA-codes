import MetaTrader5 as mt5
result=mt5.initialize()
accountinfo=mt5.account_info()
#getting account info
symbolinfo=mt5.symbol_info("XAUUSD.m")
#print("Symbolinfo: ",symbolinfo)

positionstotal=mt5.positions_total()
print("positionstotal: ",positionstotal)




