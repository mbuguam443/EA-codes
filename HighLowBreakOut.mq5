#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|Inputs                                                                  |
//+------------------------------------------------------------------+
static input long InpMagicnumber=87654;      //magic number
static double InpLots=0.01;                  //Lot size
input  int    InpBars=20;                    //bars for high/low (0=off)
input  int    InpIndexFilter=10;               // Index Filter in % (0=off)
input  int    InpStopLoss=200;               //Stoploss in points (0=off)
input  int    InpTakeProfit=0;               //Take Profit in points (0=off)
//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
double high=0,low=0;   //higest and low price of the N bars
int highIdx=0;   //index of highest bar
int lowIdx=0;    //index of lowest bar
MqlTick currentTick,previousTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //check user Inputs
   if(!CheckInputs()){return INIT_PARAMETERS_INCORRECT;}
   trade.SetExpertMagicNumber(InpMagicnumber);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //check for new bar open tick
    if(!IsNewBar()){return;}
    //get tick
    previousTick=currentTick;
    if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get current tick"); return;}
    //count open position
    int cntBuy=0,cntSell=0;
    if(!CountOpenPositions(cntBuy,cntSell)){return;}
    //check for buy position
    if(cntBuy==0 && high!=0 && previousTick.ask<high && currentTick.ask>=high && CheckIndexFilter(highIdx))
      {
       Print("Open Buy Position");
       //calculate stop loss / Take profit
       double sl=InpStopLoss==0?0:currentTick.bid-InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
       if(!NormalizePrice(sl)){ Print("Sl failed to normalize");return;}
       if(!NormalizePrice(tp)){ Print("tp failed to normalize");return;}
       trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLots,currentTick.ask,sl,tp,"HighLow Buy");
      }
    //check for Sell position
    if(cntSell==0 && low!=0 && previousTick.bid>low && currentTick.bid<=low && CheckIndexFilter(lowIdx))
      {
       Print("Open sell Position");
       //calculate stop loss / Take profit
       double sl=InpStopLoss==0?0:currentTick.ask+InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
       if(!NormalizePrice(sl)){ Print("Sl failed to normalize");return;}
       if(!NormalizePrice(tp)){ Print("tp failed to normalize");return;}
       trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLots,currentTick.bid,sl,tp,"HighLow Sell");
      }  
   
   //calculate high
   highIdx=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpBars,1);
   high=iHigh(_Symbol,PERIOD_CURRENT,highIdx);
   //calculate low
   lowIdx=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpBars,1);
   low=iLow(_Symbol,PERIOD_CURRENT,lowIdx);
   
   //Print("high: ",high," low: ",low);
   if(cntBuy==0 || cntSell==0)
     {
       DrawObjects();
     }
  
   
  }
//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+

bool CheckInputs()
{

  if(InpMagicnumber<=0)
    {
     Alert("Wrong Input:Magicnumber<=0 ");
     return false;
    }
  if(InpLots<=0)
    {
     Alert("Wrong Input:Lots<=0 ");
     return false;
    } 
   if(InpBars<0)
    {
     Alert("Wrong Input:Bars<0 ");
     return false;
    }
    if(InpIndexFilter<0 || InpIndexFilter >=50)
    {
     Alert("Wrong Input:IndexFilter<0 || InpIndexFilter >=50 ");
     return false;
    }
    if(InpStopLoss<0)
    {
     Alert("Wrong Input:StopLoss<0 ");
     return false;
    }
    if(InpTakeProfit<0)
    {
     Alert("Wrong Input:StopLoss<0 ");
     return false;
    }   

  return true;
}
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
     
     if(magicnumber==InpMagicnumber)
       {
          long type;
          if(!PositionGetInteger(POSITION_TYPE,type)){Print("failed to get Position Type number"); return false;}
          if(type==POSITION_TYPE_BUY){cntBuy++;}
          if(type==POSITION_TYPE_SELL){cntSell++;}
       }
    }
  return true;
}

bool NormalizePrice(double &price)
{
  double tickSize=0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize)){Print("Failed to get tick size"); return false;}
  price=NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
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
     
     if(magicnumber==InpMagicnumber)
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

void DrawObjects()
{
    datetime time1=iTime(_Symbol,PERIOD_CURRENT,InpBars);
    datetime time2=iTime(_Symbol,PERIOD_CURRENT,InpBars-round(InpBars*InpIndexFilter*0.01));
    datetime time3=iTime(_Symbol,PERIOD_CURRENT,round(InpBars*InpIndexFilter*0.01));
    datetime time4=iTime(_Symbol,PERIOD_CURRENT,1);
    
   if(InpIndexFilter>0){ 
    ObjectDelete(NULL,"high_");
    //high time1
    string highname = "high_" + TimeToString(time1);
    ObjectCreate(NULL,highname,OBJ_TREND,0,time1,high,time2,high);
    ObjectSetInteger(NULL,highname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,highname,OBJPROP_COLOR,clrGreen);
    //high time2
     highname = "high_" + TimeToString(time2);
    ObjectCreate(NULL,highname,OBJ_TREND,0,time2,high,time3,high);
    ObjectSetInteger(NULL,highname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,highname,OBJPROP_COLOR,clrBeige);
    //high time3
     highname = "high_" + TimeToString(time3);
    ObjectCreate(NULL,highname,OBJ_TREND,0,time3,high,time4,high);
    ObjectSetInteger(NULL,highname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,highname,OBJPROP_COLOR,clrBlue);
    ObjectDelete(NULL,"low_");
    //low time1
    string lowname = "low_" + TimeToString(time1);
    ObjectCreate(NULL,lowname,OBJ_TREND,0,time1,low,time2,low);
    ObjectSetInteger(NULL,lowname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,lowname,OBJPROP_COLOR,clrGreen);
    //low time1
     lowname = "low_" + TimeToString(time2);
    ObjectCreate(NULL,lowname,OBJ_TREND,0,time2,low,time3,low);
    ObjectSetInteger(NULL,lowname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,lowname,OBJPROP_COLOR,clrBeige);
    //low time1
     lowname = "low_" + TimeToString(time3);
    ObjectCreate(NULL,lowname,OBJ_TREND,0,time3,low,time4,low);
    ObjectSetInteger(NULL,lowname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,lowname,OBJPROP_COLOR,clrBlue);
    //low time1
    }else{
    ObjectDelete(NULL,"high_");
    //high time1
    string highname = "high_" + TimeToString(time1);
    ObjectCreate(NULL,highname,OBJ_TREND,0,time1,high,time4,high);
    ObjectSetInteger(NULL,highname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,highname,OBJPROP_COLOR,clrGreen);
    //low time1
    ObjectDelete(NULL,"low_");
     string lowname = "low_" + TimeToString(time3);
    ObjectCreate(NULL,lowname,OBJ_TREND,0,time1,low,time4,low);
    ObjectSetInteger(NULL,lowname,OBJPROP_WIDTH,3);
    ObjectSetInteger(NULL,lowname,OBJPROP_COLOR,clrBlue);
    }
    
    
    
}
//check if high/low
bool CheckIndexFilter(int index)
{
   if(InpIndexFilter>0 && (index<=round(InpBars*InpIndexFilter*0.01) || index >InpBars-round(InpBars*InpIndexFilter*0.01)))
     {
      return false;
     }
   return true;
}