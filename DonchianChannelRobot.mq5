#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|Defines                                                           |
//+------------------------------------------------------------------+
#define INDICATOR_NAME "DonchanChannel"
//+------------------------------------------------------------------+
//|Inputs                                                            |
//+------------------------------------------------------------------+
input  group      "=====General input==="
static input long InpMagicNumber=76567;   //magic number
static input double InpLotSize=0.01;       //Lot Size
enum SL_TP_MODE_ENUM{
   SL_TP_MODE_PCT,    //sl/tp in % of the channel
   SL_TP_MODE_POINTS  //sl/tp in points
};
input  SL_TP_MODE_ENUM InpSLTPMode =SL_TP_MODE_PCT; // sl/tp in mode
input  int        InpStopLoss =200;        //stop loss in %/points (0=ff)
input  int        InpTakeProfit=600;       //Take Profit in %/points (0=ff)
input  bool       InpCloseSignal=false;    //close trade by opposite signal
input  int        InpSizeFilter =0;        //size filter in points (0=off)
input  group      "=====Donchian Channel ==="
input  int InpPeriod   =20;                //Period
input  int InpOffset   =0;                 //Offset %of the channel
input  color InpColor  =clrBlue;           //color



//+------------------------------------------------------------------+
//|Global variables                                                  |
//+------------------------------------------------------------------+
int handle;
double bufferUpper[];
double bufferLower[];

MqlTick currentTick;
CTrade trade;
datetime openTimeBuy=0;
datetime openTimeSell=0;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
  {
    //check user inputs
    if(InpMagicNumber<=0)
      {
       Alert("wrong input: MagicNumber<=0");
       return INIT_PARAMETERS_INCORRECT;
      }
    if(InpLotSize<=0 || InpLotSize>10)
      {
       Alert("wrong input: LotSize<=0 or LotSize>10 ");
       return INIT_PARAMETERS_INCORRECT;
      }
       if(InpSizeFilter <0)
      {
       Alert("wrong input: SizeFilter <0 ");
       return INIT_PARAMETERS_INCORRECT;
      }
      if(InpStopLoss<0)
      {
       Alert("wrong input: StopLoss<=0 ");
       return INIT_PARAMETERS_INCORRECT;
      }
      if(InpTakeProfit<0)
      {
       Alert("wrong input: TakeProfit<0 ");
       return INIT_PARAMETERS_INCORRECT;
      }
      if(InpStopLoss==0 && !InpCloseSignal)
      {
       Alert("wrong input: No stoploss no close signal ");
       return INIT_PARAMETERS_INCORRECT;
      }
      
       if(InpPeriod<=1)
      {
       Alert("wrong input: Donchian Channel Period<=0");
       return INIT_PARAMETERS_INCORRECT;
      }
    if(InpOffset<0 || InpOffset>=50)
      {
       Alert("wrong input: Donchian channel offset<0 or Donchian channel offset>=50 ");
       return INIT_PARAMETERS_INCORRECT;
      }
      //set the magic number
      trade.SetExpertMagicNumber(InpMagicNumber);
      //create RSI handle
      handle=iCustom(_Symbol,PERIOD_CURRENT,INDICATOR_NAME,InpPeriod,InpOffset,InpColor);
      if(handle==INVALID_HANDLE){Print("Failed to create indicator handle");  return INIT_FAILED;} 
      //set Buffer as series
      ArraySetAsSeries(bufferUpper,true);
      ArraySetAsSeries(bufferLower,true);
      //draw indicator
      ChartIndicatorDelete(NULL,0,"Donchian ("+IntegerToString(InpPeriod)+")");
      ChartIndicatorAdd(NULL,0,handle);
            
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    //release the indicator
    if(handle!=INVALID_HANDLE){
    
    ChartIndicatorDelete(NULL,0,"Donchian ("+IntegerToString(InpPeriod)+")");
    IndicatorRelease(handle);}
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //check if the new tick is a new bar open tick
    if(!IsNewBar()){return;}
    //get the current Tick
    if(!SymbolInfoTick(_Symbol,currentTick)){Print("unable to get current Tick"); return;}
    //get the Donchian Channel value
    int values=CopyBuffer(handle,0,1,1,bufferUpper)+CopyBuffer(handle,1,1,1,bufferLower);
    if(values!=2){Print("unable to get indicator values"); return;}
    
    
    Comment("BufferUpper[0]: ",bufferUpper[0],"\nBufferLower[0]: ",bufferLower[0]);  
    
    //count positions
    int cntBuy,cntSell;
    if(!CountOpenPositions(cntBuy,cntSell)){ Print("unable to count open positions"); return;}
    //check Size filter
    if(InpSizeFilter >0 && (bufferUpper[0]-bufferLower[0])<InpSizeFilter*_Point){ Print("chanel filtered size: ",bufferUpper[0]-bufferLower[0]);return;}
     
    //check for buy Positions
    if(cntBuy==0 && currentTick.ask<=bufferLower[0]  && openTimeBuy!=iTime(_Symbol,PERIOD_CURRENT,0))
      {
         Print("Buy Now ");
         openTimeBuy=iTime(_Symbol,PERIOD_CURRENT,0);
         if(InpCloseSignal){if(!ClosePositions(2)){return;}}
         double sl=0;
         double tp=0;
         if(InpSLTPMode==SL_TP_MODE_PCT)
           {
              sl=InpStopLoss==0?0:currentTick.bid-(bufferUpper[0]-bufferLower[0])*InpStopLoss*0.01;
              tp=InpTakeProfit==0?0:currentTick.bid+(bufferUpper[0]-bufferLower[0])*InpTakeProfit*0.01;
           }else{
              sl=InpStopLoss==0?0:currentTick.bid-InpStopLoss*_Point;
              tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
           }
         
         
         if(!NormalizePrice(sl)){Print("Unable to normalize sl"); return;}
         if(!NormalizePrice(tp)){Print("Unable to normalize tp"); return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"Donchian Channel Buy"); 
      }
     
     //check for sell Positions
    if(cntSell==0 && currentTick.bid >=bufferUpper[0] && openTimeSell!=iTime(_Symbol,PERIOD_CURRENT,0))
      {
         Print("Sell Now ");
         openTimeSell=iTime(_Symbol,PERIOD_CURRENT,0);
         if(InpCloseSignal){if(!ClosePositions(1)){return;}}
         double sl=0;
         double tp=0;
         if(InpSLTPMode==SL_TP_MODE_PCT)
           {
              sl=InpStopLoss==0?0:currentTick.ask+(bufferUpper[0]-bufferLower[0])*InpStopLoss*0.01;
              tp=InpTakeProfit==0?0:currentTick.ask-(bufferUpper[0]-bufferLower[0])*InpTakeProfit*0.01;
           }else{
              sl=InpStopLoss==0?0:currentTick.ask+InpStopLoss*_Point;
              tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
           }
         if(!NormalizePrice(sl)){Print("Unable to normalize sl"); return;}
         if(!NormalizePrice(tp)){Print("Unable to normalize tp"); return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"Donchian Channel Sell"); 
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
