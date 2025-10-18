//+------------------------------------------------------------------+
//|                                                 MAPullBackEA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|include                                                           |
//+------------------------------------------------------------------+
#include<Trade/Trade.mqh>
#include<Trade/PositionInfo.mqh>
//+------------------------------------------------------------------+
//|inputs                                                            |
//+------------------------------------------------------------------+
input group "====General==="
static input long InpMagicnumber=5775;    //magic number
static input double InpLotsize=0.01;      //lot size
input group "====Trading===="
input double InpTriggerLv1   =2.0;        //trigger level as factor of ATR
input double InpStopLossATR  =5.0;        //stop loss as a factor of ATR (0=ff)
enum TP_MODE_ENUM{
   TP_MODE_ATR,  //TP as factor of ATR
   TP_MODE_MA,   //tp as MA   
};
input TP_MODE_ENUM InpTPMode=TP_MODE_ATR;  //tp mode
input double       InpTakeProfitATR =4.0;   //tp as a factor of ATR (0=off)
input bool         InpCloseBySignal =false;  //close trades by opposite signal
input group "====Moving Average===="
input int          InpPeriodMA =21;       //MA period
input group "====ATR===="
input int          InpPeriodATR =21;       //ATR period
//+------------------------------------------------------------------+
//|Global Variable                                                   |
//+------------------------------------------------------------------+
int handleMA;
int handleATR;
double bufferMA[];
double bufferATR[];
MqlTick tick;
CTrade trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //check user inputs
   if(!CheckInputs()){ return INIT_PARAMETERS_INCORRECT; }
   //set magic number to trade object
   trade.SetExpertMagicNumber(InpMagicnumber);
   //create indicator handles
   handleMA=iMA(_Symbol,PERIOD_CURRENT,InpPeriodMA,0,MODE_SMA,PRICE_CLOSE);
   if(handleMA==INVALID_HANDLE)
     {
      Alert("MA failed indicator");
      return INIT_FAILED;
     }
   handleATR=iATR(_Symbol,PERIOD_CURRENT,InpPeriodATR);
   if(handleATR==INVALID_HANDLE)
     {
      Alert("ATR failed indicator");
      return INIT_FAILED;
     }  
   //set buffer in series
   ArraySetAsSeries(bufferMA,true);
   ArraySetAsSeries(bufferATR,true);
   
   //Draw chart indicator
   ChartIndicatorDelete(NULL,0,"MA("+IntegerToString(InpPeriodMA)+")");
   ChartIndicatorAdd(NULL,0,handleMA);  
   ChartIndicatorDelete(NULL,1,"ATR("+IntegerToString(InpPeriodATR)+")");
   ChartIndicatorAdd(NULL,1,handleATR);  
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      //release the indicator
      if(handleMA!=INVALID_HANDLE)
        {
         ChartIndicatorDelete(NULL,0,"MA("+IntegerToString(InpPeriodMA)+")");
         IndicatorRelease(handleMA);
        }
      if(handleATR!=INVALID_HANDLE)
        {
         ChartIndicatorDelete(NULL,1,"ATR("+IntegerToString(InpPeriodATR)+")");
         IndicatorRelease(handleATR);
        }  
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //get current tick
   if(!SymbolInfoTick(_Symbol,tick))
     {
      Print("Failed to get current tick");
      return;
     }
   int values=CopyBuffer(handleMA,0,0,1,bufferMA)+CopyBuffer(handleATR,0,0,1,bufferATR);
   if(values!=2)
     {
      Print("Failed to get indicator values");
      return;
     }  
     
   double MA=bufferMA[0];
   double ATR=bufferATR[0];
   
   int cntBuy, cntSell;
   CountOpenPositions(cntBuy,cntSell);
   
   //check for a new buy position
   if(cntBuy==0 && tick.ask<= MA-ATR*InpTriggerLv1)
     {
     //close a sell trade
      if(InpCloseBySignal){ClosePositions(false);}
        
         //calculate sl and tp
         double sl=InpStopLossATR==0?0:tick.bid-ATR*InpStopLossATR;
         double tp=InpTPMode==TP_MODE_MA?0:InpTakeProfitATR==0?0:tick.ask+ATR*InpTakeProfitATR;
         //normalize
         if(!NormalizePrice(sl,sl)){return;}
         if(!NormalizePrice(tp,tp)){return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotsize,tick.ask,sl,tp,"MA pullback Buy");
         
        
     }
     
    //check for a new sell position
   if(cntSell==0 && tick.bid>= MA+ATR*InpTriggerLv1)
     {
     //close a sell trade
      if(InpCloseBySignal){ClosePositions(true);}
        
         //calculate sl and tp
         double sl=InpStopLossATR==0?0:tick.bid+ATR*InpStopLossATR;
         double tp=InpTPMode==TP_MODE_MA?0:InpTakeProfitATR==0?0:tick.ask-ATR*InpTakeProfitATR;
         //normalize
         if(!NormalizePrice(sl,sl)){return;}
         if(!NormalizePrice(tp,tp)){return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotsize,tick.bid,sl,tp,"MA pullback Sell");
         
        
     } 
     
     
   //check buy position take profit at MA
   if(cntBuy >0 && InpTPMode==TP_MODE_MA && tick.bid>=MA){ClosePositions(true);}
   //check sell position take profit at MA
   if(cntSell >0 && InpTPMode==TP_MODE_MA && tick.ask<=MA){ClosePositions(false);}       
   
   
   DrawObjects(MA,ATR);
   
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+

bool CheckInputs()
{
  if(InpMagicnumber<=0)
    {
     Alert("Wrong Input: InpMagicnumber<=0");
     return false;
    }
  if(InpLotsize<=0)
    {
     Alert("Wrong Input: InpLotsize<=0");
     return false;
    }
  if(InpTriggerLv1<=0)
    {
     Alert("Wrong Input: InpTriggerLv1<=0");
     return false;
    }
   if(InpStopLossATR<0)
    {
     Alert("Wrong Input: InpStopLossATR<0");
     return false;
    }
   if(InpTPMode==TP_MODE_ATR && InpTakeProfitATR <0)
    {
     Alert("Wrong Input: Take profit <0");
     return false;
    }
    if(InpPeriodMA<=1)
    {
     Alert("Wrong Input: Ma period <=1");
     return false;
    }
    if(InpPeriodATR<=1)
    {
     Alert("Wrong Input: ATR period <=1");
     return false;
    }       
  return true;
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

//draw trigger levels above and beneath the MA
void DrawObjects(double maValue, double atrValue)
{
    ObjectDelete(NULL,"TriggerBuy");
    ObjectCreate(NULL,"TriggerBuy",OBJ_HLINE,0,0,maValue-atrValue*InpTriggerLv1);
    ObjectSetInteger(NULL,"TriggerBuy",OBJPROP_COLOR,clrBlue);
    
    
    ObjectDelete(NULL,"TriggerSell");
    ObjectCreate(NULL,"TriggerSell",OBJ_HLINE,0,0,maValue+atrValue*InpTriggerLv1);
    ObjectSetInteger(NULL,"TriggerSell",OBJPROP_COLOR,clrBlue);
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