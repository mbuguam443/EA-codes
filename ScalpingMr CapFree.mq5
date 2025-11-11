//+------------------------------------------------------------------+
//|                                           ScalpingMr CapFree.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

enum LOT_MODE_ENUM{
  LOT_MODE_FIXED,  // fixed lots
  LOT_MODE_MONEY,  //lot based on money
  LOT_MODE_PCT_ACCOUNT //lots based on percent of account (lot must be %)
};
input LOT_MODE_ENUM InpLotMode=LOT_MODE_PCT_ACCOUNT; //lot mode

input double InpLots=0.01;       //lots / money/ %

input ENUM_TIMEFRAMES Timeframe=PERIOD_M5;
input int BarsN=5;

int OnInit()
  {
//---
   
//---
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
//---
   
  }
//+------------------------------------------------------------------+



//check if we have a bar open tick
bool IsNewBar()
{
   static datetime previousTime=0;
   datetime currentTime=iTime(_Symbol,Timeframe,0);
   if(previousTime!=currentTime)
     {
       previousTime=currentTime;
       return true;
     }
   
   return false;
}


double findHigh()
{
    double highestHigh=0;
    for(int i=0;i<200;i++)
      {
       double high=iHigh(_Symbol,Timeframe,i);
       if(i>BarsN && iHighest(_Symbol,Timeframe,MODE_HIGH,BarsN*2+1,i-BarsN)==i)
         {
          if(high>highestHigh)
            {
             return high;
            }
         }
         highestHigh=MathMax(high,highestHigh);
      }
    return -1;
}

double findLow()
{
    double lowestLow=DBL_MAX;
    for(int i=0;i<200;i++)
      {
       double low=iLow(_Symbol,Timeframe,i);
       if(i>BarsN && iLowest(_Symbol,Timeframe,MODE_LOW,BarsN*2+1,i-BarsN)==i)
         {
          if(low<lowestLow)
            {
             return low;
            }
         }
         lowestLow=MathMin(low,lowestLow);
      }
    return -1;
}

//calculate lots

bool CalculateLots(double slDistance, double &lots)
{
  lots=0.0;
  
  if(InpLotMode==LOT_MODE_FIXED)
    {
     lots=InpLots;
    }else
    {
     double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
     double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
     double volumestep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
     
     double riskMoney=InpLotMode==LOT_MODE_MONEY?InpLots:AccountInfoDouble(ACCOUNT_EQUITY)*InpLots*0.01;
     double moneyVolumeStep=(slDistance/tickSize)*tickValue*volumestep;
     
     lots=MathFloor(riskMoney/moneyVolumeStep)*volumestep;
        
    }
    Print("Calculated  lots: ",lots);
    //check calculated lots
    if(!CheckLots(lots)){return false;}
    
  return true;
}


//check lots
bool CheckLots(double &lots)
{
  double min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  
  if(lots<min)
    {
     Print("Lotsize will be set to minimum lot value lots: ",lots);
     lots=min;
    }
    if(lots>max)
    {
     Print("Lotsize will be set to maximum lot value, lots: ",lots);
     lots=max;
    }
    
    lots=(int)MathFloor(lots/step)*step;
    Print("Calculated check lots: ",lots," max | min :",max," ",min);
  return true;
}