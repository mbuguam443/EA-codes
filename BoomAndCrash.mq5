//+------------------------------------------------------------------+
//|                                                 BoomAndCrash.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

input int atrperiod=8;
input int numberbar=1;

input int TakeProfit=600;
input int SlPoints=200;
input double lotsize=0.01;


int totalBars;

int handleBoomCrash;

int OnInit()
  {
   handleBoomCrash=iCustom(_Symbol,PERIOD_CURRENT,"Market\Boom and crash smasher.ex5",atrperiod,numberbar,false,0,false,false);
   totalBars=iBars(_Symbol,PERIOD_CURRENT);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    
    int bars=iBars(_Symbol,PERIOD_CURRENT);
    if(totalBars!=bars)
      {
       totalBars=bars;
       double buyBuffer[],SellBuffer[];
       CopyBuffer(handleBoomCrash,0,1,1,SellBuffer);
       CopyBuffer(handleBoomCrash,1,1,1,buyBuffer);
       //CopyBuffer(handleBoomCrash,0,1,1,1,SellBuffer);
       ArraySetAsSeries(buyBuffer,true);
       ArraySetAsSeries(SellBuffer,true);
       
       if(buyBuffer[0]>0)
         {
           trade.PositionClose(_Symbol);
           Print("Buy Now: ",buyBuffer[0]);
           double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
           double tp=entry+TakeProfit*_Point;
           double sl=SlPoints==0? buyBuffer[0] : entry-SlPoints*_Point;
           
           trade.Buy(lotsize,_Symbol,entry,buyBuffer[0],tp,"Buy Now ");
         }
       if(SellBuffer[0]>0)
         {
           trade.PositionClose(_Symbol);
           Print("Sell Now: ",SellBuffer[0]);
           double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
           double tp=entry-TakeProfit*_Point;
           double sl=SlPoints==0? buyBuffer[0] : entry+SlPoints*_Point;
           
           trade.Sell(lotsize,_Symbol,entry,buyBuffer[0],tp,"Sell Now ");
         }  
      }
   
  }
//+------------------------------------------------------------------+
