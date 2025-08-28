#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include<Trade/Trade.mqh>
#include<Trade/PositionInfo.mqh>
//+------------------------------------------------------------------+
//|inputs                                                            |
//+------------------------------------------------------------------+
input group "===General=="
static input long  InpMagicnumber         =98768;       //magic number
static input double InpLotsize            =0.01;        //LotSize

input group "===Input==="
input ENUM_TIMEFRAMES InpTimeFrame        =PERIOD_M5;   //Time frame
input int   InpStreak                     =3;           //candle streak
input int   InpSizeFilter                 =0;           //Size Filter (0=off)
input int   InpStopLoss                   =200;         //Stop loss in points (0=off)
input int   InpTakeProfit                 =600;           //take profit in points (0=off)
input int   InpTimeExit                   =22;          //Time exit hour (-1=off)
//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
MqlTick tick;
CTrade trade;





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!CheckInput()){ return INIT_PARAMETERS_INCORRECT; }
   //set Magic number to trade object
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
    //check if the bar open tick
    if(!IsNewBar()){ return ;}
    //Draw time exit
    if(InpTimeExit>0)
      {
       DrawObjects();
      }
    
    //get current tick
    if(!SymbolInfoTick(_Symbol,tick)){Print("Failed to get current tick"); return;}
    //count open positions 
    int cntBuy=0,cntSell=0;
    CountOpenPositions(cntBuy,cntSell);
    
    //check for new buy position
    if(cntBuy==0 && CheckBars(true))
      {
       Print("Open Buy");
       //calculate stoploss and take profit
       double sl=InpStopLoss==0?0:tick.bid-InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:tick.bid+InpTakeProfit*_Point;
       //Normalize Price
       if(!NormalizePrice(tp)){return;}
       if(!NormalizePrice(sl)){return;}
       //open buy Position
       trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotsize,tick.ask,sl,tp,"Streak Buy");
      }
    //check for new sell position
    if(cntSell==0 && CheckBars(false))
      {
       Print("Open Sell");
       //calculate stoploss and take profit
       double sl=InpStopLoss==0?0:tick.ask+InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:tick.ask-InpTakeProfit*_Point;
       //Normalize Price
       if(!NormalizePrice(tp)){return;}
       if(!NormalizePrice(sl)){return;}
       //open buy Position
       trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotsize,tick.bid,sl,tp,"Streak Sell");
      }  
    //check for time exit
    MqlDateTime dt;
    TimeCurrent(dt);
    if(dt.hour==InpTimeExit && dt.min <3)
      {
       ClosePositions(0);
      }
   
  }
//+------------------------------------------------------------------+
//|Custom functions                                                  |
//+------------------------------------------------------------------+

bool CheckInput(){
  
  if(InpMagicnumber<=0)
    {
      Alert("Wrong input: Magicnumber<=0");
      return false;
    }
   if(InpLotsize<=0)
    {
      Alert("Wrong input: Lotsize<=0");
      return false;
    } 
    if(InpTimeFrame==PERIOD_CURRENT)
    {
      Alert("Wrong input: InpTimeFrame==PERIOD_CURRENT");
      return false;
    } 
    if(InpStreak<=0)
    {
      Alert("Wrong input: Streak<=0");
      return false;
    }
    if(InpSizeFilter<0)
    {
      Alert("Wrong input: SizeFilter<0");
      return false;
    }
    if(InpStopLoss<0)
    {
      Alert("Wrong input: StopLoss<0");
      return false;
    }
    if(InpTakeProfit<0)
    {
      Alert("Wrong input: TakeProfit<0");
      return false;
    }
    if(InpTimeExit<-1 || InpTimeExit>23 )
    {
      Alert("Wrong input: InpTimeExit<-1 || InpTimeExit>23");
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

//check bars

bool CheckBars(bool buy_sell)
{
    //get bars
    MqlRates rates[];
    ArraySetAsSeries(rates,true);
    
    if(!CopyRates(_Symbol,InpTimeFrame,0,InpStreak+1,rates)){Print("Failed to get Rates"); return false;}
    
    //check conditions
    for(int i=InpStreak;i>0;i--)
      {
       bool isGreen=rates[i].open<=rates[i].close;
       double size=MathAbs(rates[i].open-rates[i].close);
       if(buy_sell && (!isGreen || (InpSizeFilter>0 && size < InpSizeFilter*_Point))){return false;}
       if(!buy_sell && (isGreen || (InpSizeFilter>0 && size < InpSizeFilter*_Point))){return false;}
        
      }
    
    return true;
}
//Normalizing Symbol
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

  string streakclose = "streak_close_" + IntegerToString(GetTickCount());
  if(InpTimeFrame >0)
    {
      ObjectCreate(NULL,streakclose,OBJ_VLINE,0,InpTimeFrame*60,0);
      ObjectSetString(NULL,streakclose,OBJPROP_TOOLTIP,"close of the range \n"+TimeToString(InpTimeFrame*60,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,streakclose,OBJPROP_COLOR,clrRed);
      ObjectSetInteger(NULL,streakclose,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,streakclose,OBJPROP_BACK,true);
    }
    
 
    
    
   //refresh chart    
   ChartRedraw(); 

}