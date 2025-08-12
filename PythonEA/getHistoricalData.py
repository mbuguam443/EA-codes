import MetaTrader5 as mt5
import pandas as pd
result=mt5.initialize()
accountinfo=mt5.account_info()
#getting account info
symbolinfo=mt5.symbol_info("XAUUSD.m")
#print("Symbolinfo: ",symbolinfo)

#get data from bars
data=mt5.copy_rates_from_pos("XAUUSD.m",mt5.TIMEFRAME_M1,0,1000)
#print(data)
dataFrames=pd.DataFrame(data)
print(dataFrames)





