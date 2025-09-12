//+------------------------------------------------------------------+
//|                                               StocasticRobot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Slow Setting"
input int SlowPeriod=150;
input ENUM_MA_METHOD SlowMethod=MODE_LWMA;
input ENUM_APPLIED_PRICE SlowPrice=PRICE_CLOSE;
int handleSlowHMA;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double DailyProfitTarget=10; //Daily Profit Target in %
input double DailyLossStop=-10; //Daily Stop in %


double profitClosed;
//+------------------------------------------------------------------+
//|Lots sizing                                                       |
//+------------------------------------------------------------------+
enum LOT_MODE_ENUM{
  LOT_MODE_FIXED,  // fixed lots
  LOT_MODE_MONEY,  //lot based on money
  LOT_MODE_PCT_ACCOUNT //lots based on percent of account (lot must be %)
};
input LOT_MODE_ENUM InpLotMode=LOT_MODE_PCT_ACCOUNT; //lot mode

input double InpLots=0.01;       //lots / money/ %
//+------------------------------------------------------------------+
//|include                                                           |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
enum SIGNAL_MODE{
    EXIT_CROSS_NORMAL,    //exit body to (upper(sell),lower(buy)) level cross normal
    ENTRY_CROSS_NORMAL,   //entry level to (upper(sell),lower (buy)) body cross normal
    
    EXIT_CROSS_REVERSED,    //exit body to (upper(buy),lower(sell)) level cross reversed
    ENTRY_CROSS_REVERSED,   //entry level to (upper(sell),lower(buy)) body cross reversed    
};
//+------------------------------------------------------------------+
//|inputs                                                            |
//+------------------------------------------------------------------+
input group "===General==="
static input long InpMagicNumber=45454; //magic number
static input double InpLotSize=0.01;    //lot size
input group "====Trading==="
input SIGNAL_MODE InpSignalMode=EXIT_CROSS_NORMAL; // signal mode
input int  InpStopLoss =200;            //Stop loss in points (0=off)
input int  InpTakeProfit =0;            //TakeProfit in points (0=off)
input bool InpCloseSignal=false;        //close trade by opposite signal
input group "===Stocatic==="
input int  InpKPeriod=21;               //K period
input int  InpUpperLevel=80;            //Upper Level
input group "===Clear Bars Filter==="
input bool  InpClearBarsReversed =false;  //reverse clear bar filter
input int   InpClearBars=0;               //clear bars (0=off)
//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int handle;
double bufferMain[];
MqlTick cT;
CTrade trade;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //check user inputs
   if(!CheckUserInputs()){return INIT_PARAMETERS_INCORRECT;}
   trade.SetExpertMagicNumber(InpMagicNumber);
   //create indicator handle
   handle=iStochastic(_Symbol,PERIOD_CURRENT,InpKPeriod,1,3,MODE_SMA,STO_LOWHIGH);
   if(handle==INVALID_HANDLE)
     {
      Alert("Failed to load stocastic indicator");
      return INIT_FAILED;
     }
   //set Buffer Series
   ArraySetAsSeries(bufferMain,true);  
   profitClosed=CalculateDailyProfitClosed();
   //
   handleSlowHMA=iCustom(_Symbol,PERIOD_CURRENT,"Market/HMA Color with Alerts MT5.ex5","",SlowPeriod,SlowMethod,SlowPrice,"",false,false,false,false,"","",false);
   if(handleSlowHMA==INVALID_HANDLE){
     Print("Slow Indicator Failed");
    return INIT_FAILED;
   }else{
    Print("Slow ",SlowPeriod," loaded successfully");
   }  
     
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
     double accountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
     double accountEquity=AccountInfoDouble(ACCOUNT_EQUITY);
     double profitOpen=accountEquity-accountBalance;
     double profitDay=profitOpen+profitClosed;
     
     
     
     
     
     Comment(" Profit Open: ",DoubleToString(profitOpen,2),
             " Profit Closed: ",DoubleToString(profitClosed,2),
             " Profit for the  Day: ",DoubleToString(profitDay,2),
             " Target Profit: ",DoubleToString((DailyProfitTarget*0.01*AccountInfoDouble(ACCOUNT_BALANCE)),2),
             " Stop Loss : ",DoubleToString((DailyLossStop*0.01*AccountInfoDouble(ACCOUNT_BALANCE)),2));
             
    if(profitDay >(DailyProfitTarget*0.01*AccountInfoDouble(ACCOUNT_BALANCE)) || profitDay <(DailyLossStop*0.01*AccountInfoDouble(ACCOUNT_BALANCE)))
      {
        for(int i=PositionsTotal()-1;i>=0;i--)
          {
            ulong posTicket=PositionGetTicket(i);
            trade.PositionClose(posTicket);
          }
      } 
    //check new bar   
    if(!IsNewBar()){return;}
    //get the Current Tick 
    if(!SymbolInfoTick(_Symbol,cT)){Print("Failed to get Current tick"); return;}
    //get indicator values
    if(CopyBuffer(handle,0,0,3+InpClearBars,bufferMain)!=(3+InpClearBars)){Print("failed to get indicator values"); return;}
    //Count Open Position
    int cntBuy,cntSell;
    if(!CountOpenPositions(cntBuy,cntSell)){Print("Failed to count Open Position"); return;}
    
    
    double slowBuffer[];
    CopyBuffer(handleSlowHMA,0,1,2,slowBuffer);
    
    
    //check for buy position
    if(CheckSignal(true,cntBuy) && CheckClearBars(true))
    {
     Print("Open Buy Position");
     if(InpCloseSignal){if(!ClosePositions(2)){return;}}
     double sl=InpStopLoss==0?0:cT.bid-InpStopLoss*_Point;
     double tp=InpTakeProfit==0?0:cT.bid+InpTakeProfit*_Point;
     if(!NormalizePrice(sl)){Print("Failed to Normalize Sl Price"); return;}
     if(!NormalizePrice(tp)){Print("Failed to Normalize Tp Price"); return;}
     //calculate lots
          double lots;
          if(!CalculateLots(cT.ask-sl,lots)){return;}
          
          if(slowBuffer[1] < slowBuffer[0])
        {
          trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,lots,cT.ask,sl,tp,"Stocastic Buy");
        }
     
    }
    //check for Sell position
    if(CheckSignal(false,cntSell)&& CheckClearBars(false))
    {
     Print("Open Sell Position");
     if(InpCloseSignal){if(!ClosePositions(1)){return;}}
     double sl=InpStopLoss==0?0:cT.ask+InpStopLoss*_Point;
     double tp=InpTakeProfit==0?0:cT.ask-InpTakeProfit*_Point;
     if(!NormalizePrice(sl)){Print("Failed to Normalize Sl Price"); return;}
     if(!NormalizePrice(tp)){Print("Failed to Normalize Tp Price"); return;}
     //calculate lots
          double lots;
          if(!CalculateLots(sl-cT.bid,lots)){return;}
          if(slowBuffer[1] > slowBuffer[0])
        {
           trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,lots,cT.bid,sl,tp,"Stocastic Sell");
        }
    }
  }
//+------------------------------------------------------------------+
//|Custom functions                                                  |
//+------------------------------------------------------------------+


//check User Inputs

bool CheckUserInputs()
{
  if(InpMagicNumber<=0)
    {
     Alert("MagicNumber<=0");
     return false;
    }
  if(InpLotSize<=0 || InpLotSize >10)
    {
     Alert("LotSize<=0 or LotSize >10");
     return false;
    }
  if(InpStopLoss<0 )
    {
     Alert("StopLoss<0");
     return false;
    } 
    if(InpTakeProfit<0 )
    {
     Alert("InpTakeProfit<0");
     return false;
    } 
    if(!InpCloseSignal && InpStopLoss==0)
    {
     Alert("CloseSignal is false  StopLoss==0");
     return false;
    }
    if(InpKPeriod<=0)
    {
     Alert("KPeriod<=0");
     return false;
    }
    if(InpUpperLevel<=50 || InpUpperLevel>=100 )
    {
     Alert("UpperLevel<=50 or UpperLevel >=100");
     return false;
    }
    if(InpClearBars<0)
    {
     Alert("ClearBars<0");
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

//check for new Signals
bool CheckSignal(bool buy_sell,int cntBuySell)
{
  //return false if a position is open
  if(cntBuySell>0){return false;}
  
  //check crossovers
  int lowerlevel=100-InpUpperLevel;
  bool upperExitCross=bufferMain[1]>=InpUpperLevel && bufferMain[2]<InpUpperLevel; //body to upperlevel
  bool upperEntryCross=bufferMain[1]<=InpUpperLevel && bufferMain[2]>InpUpperLevel; //upperlevel to body
  bool lowerExitCross=bufferMain[1]<=lowerlevel && bufferMain[2]>lowerlevel; //body to lowerlevel
  bool lowerEntryCross=bufferMain[1]>=lowerlevel && bufferMain[2]<lowerlevel; //lower level to body
  
  //check signal
  switch(InpSignalMode)
    {
     case EXIT_CROSS_NORMAL : return ((buy_sell && lowerExitCross) || (!buy_sell && upperExitCross));
     case ENTRY_CROSS_NORMAL : return ((buy_sell && lowerEntryCross) || (!buy_sell && upperEntryCross));  
     case EXIT_CROSS_REVERSED : return ((buy_sell && upperExitCross) || (!buy_sell && lowerExitCross)); 
     case ENTRY_CROSS_REVERSED : return ((buy_sell && upperEntryCross) || (!buy_sell && lowerEntryCross)); 
     
    }
  
  return false;
}

//check clear bar filter
bool CheckClearBars(bool buy_sell)
{
  //return true if filter is inactive
  if(InpClearBars==0){return true;}
  
  bool checkLower=((buy_sell && (InpSignalMode==EXIT_CROSS_NORMAL || InpSignalMode==ENTRY_CROSS_NORMAL))
                  || (!buy_sell && (InpSignalMode==EXIT_CROSS_REVERSED || InpSignalMode==ENTRY_CROSS_REVERSED)));
  
  for(int i=3;i<(3+InpClearBars);i++)
    {
       //check upper level crosses
       if(!checkLower && ((bufferMain[i-1]>InpUpperLevel && bufferMain[i]<=InpUpperLevel)
                         || (bufferMain[i-1]<InpUpperLevel && bufferMain[i] >=InpUpperLevel)))
         {
           if(InpClearBarsReversed)
             {
              Print("we have detected close crossover between ",(i-1)," and ",i," at the upper side");
              return true;
             }else{
             Print("you said No so ",buy_sell?"buy":"sell"," position will not  be open bz signal cross of upper level at index",(i-1),"->",i);
             return false;
             }
         }
         
         if(checkLower && ((bufferMain[i-1]<(100-InpUpperLevel) && bufferMain[i]>=(100-InpUpperLevel))
                         || (bufferMain[i-1]>(100-InpUpperLevel) && bufferMain[i] <=(100-InpUpperLevel))))
         {
           if(InpClearBarsReversed)
             {
               Print("we open ",buy_sell?"buy":"sell","position bz have detected close crossover between ",(i-1)," and ",i," at the lower side ");
              return true;
             }else{
             Print("you said No so  ",buy_sell?"buy":"sell"," Position will not be happen bz close signal cross of lower level at index",(i-1),"->",i);
             return false;
             }
         }
    }  
    
    if(InpClearBarsReversed)
      {
       Print("end cond we are unable to open ",buy_sell?"buy":"sell","position bz no crossover detected ");
       return false;
      }else
         {
          Print("Clear bar disabled at a distance of  bar of: ",(3+InpClearBars));
          return true;
         }              
                  
  
}

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


void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
     if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
       {
         profitClosed=CalculateDailyProfitClosed();
       }
   
  }  
  
  
double CalculateDailyProfitClosed()
{
   double profit=0;
   MqlDateTime dt;
   TimeTradeServer(dt);
   dt.hour=0;
   dt.min=0;
   dt.sec=0;
   
   datetime timeDaystart=StructToTime(dt);
   datetime timeNow = TimeTradeServer();
   
   HistorySelect(timeDaystart,timeNow+100);
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
     {
        ulong dealTicket = HistoryDealGetTicket(i);
        //double dealProfit=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
        
        int dealType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealType==DEAL_ENTRY_OUT)
         {
            
         
        
        //Print("Deal Ticket: ", dealTicket," profit: ",dealProfit);
        
       
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double mydealprofit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         int type = (int)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ulong order = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
         double commission= HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         //Print("DealTicket: ", dealTicket,", Order: ", order,", Symbol: ", symbol,", Profit: ", profit,", commission ",commission);
               
            //calculate profit
              profit+=mydealprofit+commission; 
             //Print("Profit: ",DoubleToString(profit+=mydealprofit,2));  
               
            }   
            
         }
   return profit;
} 