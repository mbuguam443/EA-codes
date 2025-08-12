import MetaTrader5 as mt5
result=mt5.initialize()
accountinfo=mt5.account_info()
#getting account info
symbolinfo=mt5.symbol_info("XAUUSD.m")
#print("Symbolinfo: ",symbolinfo)
#getting points
point=mt5.symbol_info("XAUUSD.m").point
print("point: ",point)


request={
    "action":mt5.TRADE_ACTION_DEAL,
    "symbol":"XAUUSD.m",
    "volume":0.01,
    "type":mt5.ORDER_TYPE_SELL,
    "price":mt5.symbol_info_tick("XAUUSD.m").ask,
    "magic":846647,
    "comment":"python buy",
    "tp":mt5.symbol_info_tick("XAUUSD.m").ask-600*point,
    "sl":mt5.symbol_info_tick("XAUUSD.m").ask+200*point
   }
resultsorder=mt5.order_send(request)
print(resultsorder.comment)

