#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|Inputs                                                            |
//+------------------------------------------------------------------+
static input long InpMagicNumber=765678;   //magic number
static input double InpLotSize=0.01;       //Lot Size
input  int        InpRSIPeriod=21;         //rsi period
input  int        InpRSILevel =70;         //rsi upper level
input  int        InpMAPeriod=21;          //ma period
input  ENUM_TIMEFRAMES InpMaTimeFrame=PERIOD_H1; //ma timeframe
input  int        InpStopLoss =200;        //stop loss in points (0=ff)
input  int        InpTakeProfit=600;       //Take Profit in points (0=ff)
input  bool       InpCloseSignal=false;    //close trade by opposite signal
//+------------------------------------------------------------------+
//|Global variables                                                  |
//+------------------------------------------------------------------+
int handleRSI;
int handleMA;
double bufferRSI[];
double bufferMA[];
MqlTick currentTick;
CTrade trade;




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
    if(InpRSIPeriod<=1)
      {
       Alert("wrong input: RSIPeriod<=0");
       return INIT_PARAMETERS_INCORRECT;
      }
    if(InpMAPeriod<=1)
      {
       Alert("wrong input: InpMAPeriod<=0");
       return INIT_PARAMETERS_INCORRECT;
      }  
    if(InpRSILevel>=100 || InpRSILevel<=50)
      {
       Alert("wrong input: RSILevel<=50 or RSILevel>=100 ");
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
      //set the magic number
      trade.SetExpertMagicNumber(InpMagicNumber);
      //create indicator handles
      handleRSI=iRSI(_Symbol,PERIOD_CURRENT,InpRSIPeriod,PRICE_OPEN);
      if(handleRSI==INVALID_HANDLE){Print("Failed to create indicator handleRSI");  return INIT_FAILED;}
      
      handleMA=iMA(_Symbol,InpMaTimeFrame,InpMAPeriod,0,MODE_SMA,PRICE_OPEN);
      if(handleMA==INVALID_HANDLE){Print("Failed to create indicator handleMA");  return INIT_FAILED;} 
      //set bufferRSI as series
      ArraySetAsSeries(bufferRSI,true);
      //set bufferMA as series
      ArraySetAsSeries(bufferMA,true);
            
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    //release the indicator
    if(handleRSI!=INVALID_HANDLE){IndicatorRelease(handleRSI);}
    
    //release the indicator
    if(handleMA!=INVALID_HANDLE){IndicatorRelease(handleMA);}
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //get the current Tick is a new open Bar tick
    if(!IsNewBar()){return;}
      
    //get the current Tick
    if(!SymbolInfoTick(_Symbol,currentTick)){Print("unable to get current Tick"); return;}
    //get the rsi value
    int values=CopyBuffer(handleRSI,0,0,2,bufferRSI);
    if(values!=2){Print("unable to get RSI indicator values"); return;}
    
    //get the ma value
    values=CopyBuffer(handleMA,0,0,1,bufferMA);
    if(values!=1){Print("unable to get MA indicator values"); return;}
    
    
    Comment("bufferRSI[1]: ",bufferRSI[1],"\nBuffer[0]: ",bufferRSI[0],"\bufferMA[0]: ",bufferMA[0]);
    
    //count positions
    int cntBuy,cntSell;
    if(!CountOpenPositions(cntBuy,cntSell)){ Print("unable to count open positions"); return;}
    //check for buy Positions
    if(cntBuy==0 && (bufferRSI[1]<=(100-InpRSILevel) && bufferRSI[0]>(100-InpRSILevel))  && currentTick.ask > bufferMA[0])
      {
         Print("Buy Now ");
         
         if(InpCloseSignal){if(!ClosePositions(2)){return;}}
         double sl=InpStopLoss==0?0:currentTick.bid-InpStopLoss*_Point;
         double tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
         if(!NormalizePrice(sl)){Print("Unable to normalize sl"); return;}
         if(!NormalizePrice(tp)){Print("Unable to normalize tp"); return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"RSI Ma Filter Buy"); 
      }
     
     //check for sell Positions
    if(cntSell==0 && (bufferRSI[1]>=InpRSILevel && bufferRSI[0]<InpRSILevel) && currentTick.bid <bufferMA[0])
      {
         Print("Sell Now ");
         
         if(InpCloseSignal){if(!ClosePositions(1)){return;}}
         double sl=InpStopLoss==0?0:currentTick.ask+InpStopLoss*_Point;
         double tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
         if(!NormalizePrice(sl)){Print("Unable to normalize sl"); return;}
         if(!NormalizePrice(tp)){Print("Unable to normalize tp"); return;}
         trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"RSI Ma Filter Sell"); 
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
