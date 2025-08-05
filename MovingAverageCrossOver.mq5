//+------------------------------------------------------------------+
//|                                       MovingAverageCrossOver.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//|Inputs variable                                                   |
//+------------------------------------------------------------------+
input int InpFastPeriod=14;   //Fast Period
input int InpSlowPeriod=21;   //Slow Period
input int InpStopLoss=100;    //Stop loss in points
input int InpTakeProfit=400;  //Take profit in points;


//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

int fastHandle;
int slowHandle;
double fastBuffer[],slowBuffer[];
datetime openTimeBuy=0;
datetime openTimeSell=0;
CTrade trade;




int OnInit()
  {
    //check User Inputs
    if(InpFastPeriod <=0)
      {
       Alert("Fast Period wrong parameter");
       return INIT_PARAMETERS_INCORRECT;
      }
    if(InpSlowPeriod <=0)
      {
       Alert("Slow Period wrong parameter");
       return INIT_PARAMETERS_INCORRECT;
      }
    if(InpFastPeriod>=InpSlowPeriod)
      {
       Alert("Slow Period should be >= Fast Period");
       return INIT_PARAMETERS_INCORRECT;
      } 
      if(InpStopLoss<=0)
      {
       Alert("Stop Loss is <=0");
       return INIT_PARAMETERS_INCORRECT;
      }
      if(InpTakeProfit<=0)
      {
       Alert("Take Profit is <=0");
       return INIT_PARAMETERS_INCORRECT;
      } 
    //create handles  
    fastHandle=iMA(_Symbol,PERIOD_CURRENT,InpFastPeriod,0,MODE_SMA,PRICE_CLOSE);
    slowHandle=iMA(_Symbol,PERIOD_CURRENT,InpSlowPeriod,0,MODE_SMA,PRICE_CLOSE); 
    
    if(fastHandle==INVALID_HANDLE)
      {
       Alert("Fast MA Indicator  failed");
       return INIT_FAILED;
      }
    if(slowHandle==INVALID_HANDLE)
      {
       Alert("Slow MA Indicator  failed");
       return INIT_FAILED;
      }       
     
    ArraySetAsSeries(fastBuffer,true); 
    ArraySetAsSeries(slowBuffer,true);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    if(fastHandle!=INVALID_HANDLE){IndicatorRelease(fastHandle);}
    if(slowHandle!=INVALID_HANDLE){IndicatorRelease(slowHandle);}
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int values=CopyBuffer(fastHandle,0,0,2,fastBuffer);
   if(values!=2)
     {
      Print("Not enough data for fast the moving average");
      return;
     }
   values=CopyBuffer(slowHandle,0,0,2,slowBuffer);
   if(values!=2)
     {
      Print("Not enough data for Slow the moving average");
      return;
     }
     
     //check for cross buy
     if(fastBuffer[1]<=slowBuffer[1] && fastBuffer[0]>slowBuffer[0] && openTimeBuy!=iTime(_Symbol,PERIOD_CURRENT,0))
       {
        openTimeBuy=iTime(_Symbol,PERIOD_CURRENT,0);
        double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
        double sl=ask-InpStopLoss*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
        double tp=ask+InpTakeProfit*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
        trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,0.01,ask,sl,tp,"MA Cross buy");
        
       }
     //check for cross sell
     if(fastBuffer[1]>=slowBuffer[1] && fastBuffer[0]<slowBuffer[0] && openTimeSell!=iTime(_Symbol,PERIOD_CURRENT,0))
       {
        openTimeSell=iTime(_Symbol,PERIOD_CURRENT,0);
        double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
        double sl=bid+InpStopLoss*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
        double tp=bid-InpTakeProfit*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
        trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,0.01,bid,sl,tp,"MA Cross Sell");
        
       }  
  }
//+------------------------------------------------------------------+
