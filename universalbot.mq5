//+------------------------------------------------------------------+
//|                                                 universalbot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double DailyProfitTarget=40; //Daily Profit Target in %
input double DailyLossStop=20; //Daily Stop in %


double profitClosed;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum LOT_MODE_ENUM{
  LOT_MODE_FIXED,  // fixed lots
  LOT_MODE_MONEY,  //lot based on money
  LOT_MODE_PCT_ACCOUNT //lots based on percent of account (lot must be %)
};
input LOT_MODE_ENUM InpLotMode=LOT_MODE_PCT_ACCOUNT; //lot mode

input double InpLots=0.01; 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int stoploss=200;
input int takeprofit=600;
int handleuniversal;
int totalbars;
double signalup[],signaldown[];
CTrade trade;
int OnInit()
  {
   string indicatorname=ChartIndicatorName(0,0,0);
   
   Print("indicator name: ",indicatorname);
   handleuniversal=ChartIndicatorGet(0,0,indicatorname);
   if(handleuniversal==INVALID_HANDLE)
     {
      Print("it has failed to get the indicator");
     }else{
     Print("indicator loaded successfully");
      }
   totalbars=iBars(_Symbol,PERIOD_CURRENT);
   ArraySetAsSeries(signaldown,true);
   ArraySetAsSeries(signalup,true);
   profitClosed=CalculateDailyProfitClosed();
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
  
  
   int bars=iBars(_Symbol,PERIOD_CURRENT);
   if(totalbars!=bars)
     {
       totalbars=bars;
       Print("print every bar");
       CopyBuffer(handleuniversal,4,1,1,signalup);
       CopyBuffer(handleuniversal,5,1,1,signaldown);
       Print("signalup: ",signalup[0]," signaldown: ",signaldown[0]);
       if(signalup[0]>0)
         {
          Print("buy now");
          Alert("bot is live");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
          double sl=stoploss==0?signalup[0]:entry-stoploss*_Point;
          double tp=entry+takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          //calculate lots
          double lots;
          if(!CalculateLots(entry-sl,lots)){return;}
          trade.Buy(lots,_Symbol,entry,sl,tp,"universal buy");
          
         }
       if(signaldown[0]>0)
         {
           Print("sell now");
           Alert("bot is live");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double sl=stoploss==0?signaldown[0]:entry+stoploss*_Point;
          double tp=entry-takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          //calculate lots
          double lots;
          if(!CalculateLots(sl-entry,lots)){return;}
          trade.Sell(lots,_Symbol,entry,sl,tp,"universal sell");
         
         }  
     }
   
  }
//+------------------------------------------------------------------+

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