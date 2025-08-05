//+------------------------------------------------------------------+
//|                                           BollingerBandRobot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
static input long InpMagicNumber=87637; //magic number
static input double InpLotSize =0.01;   //lot size
input  bool         InpCloseByMiddleline=false; //Close by Middle Line

input int InpPeriod            =21;     //period
input double InpDeviation      =2.0;    //Deviation
input int InpStopLoss          =200;    //Stoploss in points
input int InpTakeProfit        =500;    //Take Profit (0=off) points

//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
int handle;
double upperBuffer[];
double lowerBuffer[];
double middleBuffer[];

MqlTick currentTick;
CTrade trade;
datetime openTimeBuy=0;
datetime openTimeSell=0;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpMagicNumber<=0)
     {
      Alert("magicnumber <=0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLotSize<=0)
     {
      Alert("Lotsize <=0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpPeriod<=1)
     {
      Alert("Period<=1");
      return INIT_PARAMETERS_INCORRECT;
     }
    if(InpDeviation<=0)
     {
      Alert("Deviation<=1");
      return INIT_PARAMETERS_INCORRECT;
     } 
     if(InpStopLoss<=0)
     {
      Alert("StopLoss<=0");
      return INIT_PARAMETERS_INCORRECT;
     }
     if(InpTakeProfit<0)
     {
      Alert("TakeProfit<=0");
      return INIT_PARAMETERS_INCORRECT;
     } 
     
     //set Magic Number 
     trade.SetExpertMagicNumber(InpMagicNumber);   
     //create handle indicator
     handle=iBands(_Symbol,PERIOD_CURRENT,InpPeriod,1,InpDeviation,PRICE_CLOSE);
     if(handle==INVALID_HANDLE)
       {
        Alert("Failed to Load Bollinger bands");
        return INIT_FAILED;
       }
     ArraySetAsSeries(upperBuffer,true);  
     ArraySetAsSeries(middleBuffer,true);
     ArraySetAsSeries(lowerBuffer,true);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    //release indicator handle
    if(handle!=INVALID_HANDLE)
      {
       IndicatorRelease(handle);
      }   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //check if current tick is a bar open tick
   if(!IsNewBar()){ return;}
   //Get current Tick
   if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get Tick"); return;}
   //get Indicator Values
   int values=CopyBuffer(handle,0,0,1,middleBuffer)+CopyBuffer(handle,1,0,1,upperBuffer)+CopyBuffer(handle,2,0,1,lowerBuffer);
   
   if(values!=3){Print("Indicator value failed to fetch"); return;}
   
   //count Positions
   int cntBuy,cntSell;
   if(!CountOpenPositions(cntBuy,cntSell)){return;}  
   
   //check for lower band cross to open buy position
   if(cntBuy==0 && currentTick.ask<=lowerBuffer[0] && openTimeBuy!=iTime(_Symbol,PERIOD_CURRENT,0))
   {
     openTimeBuy=iTime(_Symbol,PERIOD_CURRENT,0);
     double sl=currentTick.bid-InpStopLoss*_Point;
     double tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
     if(!NormalizePrice(sl,sl)){Print("Unable to normalize sl "); return;}
     if(!NormalizePrice(tp,tp)){Print("Unable to normalize  tp"); return;}
     
     trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"BolingerBand Buy");
   
   }
   
   //check for upper band cross to open sell position
   if(cntSell==0 && currentTick.ask>=upperBuffer[0] && openTimeSell!=iTime(_Symbol,PERIOD_CURRENT,0))
   {
     openTimeSell=iTime(_Symbol,PERIOD_CURRENT,0);
     double sl=currentTick.ask+InpStopLoss*_Point;
     double tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
     if(!NormalizePrice(sl,sl)){Print("Unable to normalize sl "); return;}
     if(!NormalizePrice(tp,tp)){Print("Unable to normalize  tp"); return;}
     
     trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"BolingerBand Sell");
   
   }
   
   if(InpCloseByMiddleline)
     {
       if(!CountOpenPositions(cntBuy,cntSell)){return;}
       if(cntBuy > 0 && currentTick.bid >=middleBuffer[0]){ClosePositions(1);}
       if(cntSell > 0 && currentTick.ask <=middleBuffer[0]){ClosePositions(2);}
        
     }
  }
//+------------------------------------------------------------------+
//|Custom functions                                                  |
//+------------------------------------------------------------------+

//check if we have a bar open tick
bool IsNewBar()
{
   static datetime previousTime=0;
   datetime currentTime=iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime)
     {
       previousTime=currentTime;
       return true;
     }
   
   return false;
}
//count open Positions
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
  cntBuy=0;
  cntSell=0;
  
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong positionTicket = PositionGetTicket(i);
     if(positionTicket<=0){Print("Failed to get Position Ticket"); return false;}
     if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position"); return false;}
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("failed to get Position magic number"); return false;}
     
     if(magicnumber==InpMagicNumber)
       {
          long type;
          if(!PositionGetInteger(POSITION_TYPE,type)){Print("failed to get Position Type number"); return false;}
          if(type==POSITION_TYPE_BUY){cntBuy++;}
          if(type==POSITION_TYPE_SELL){cntSell++;}
       }
    }
  return true;
}

bool NormalizePrice(double price, double &normalizeprice)
{
  double tickSize=0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize)){Print("Failed to get tick size"); return false;}
  normalizeprice=NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
  return true;
}


//Close open Positions
bool ClosePositions(int all_buy_sell)
{
  
  
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong positionTicket = PositionGetTicket(i);
     if(positionTicket<=0){Print("Failed to get Position Ticket"); return false;}
     if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position"); return false;}
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("failed to get Position magic number"); return false;}
     
     if(magicnumber==InpMagicNumber)
       {
          long type;
          if(!PositionGetInteger(POSITION_TYPE,type)){Print("failed to get Position Type number"); return false;}
          if(all_buy_sell==1 && type==POSITION_TYPE_SELL){continue;}
          if(all_buy_sell==2 && type==POSITION_TYPE_BUY){continue;}
           trade.PositionClose(positionTicket);
          if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
            {
             Print("Failed to Close the Position ticket: "+(string)positionTicket," result: "+(string)trade.ResultRetcode(),": ",trade.ResultRetcodeDescription());
            } 
       }
    }
  return true;
}