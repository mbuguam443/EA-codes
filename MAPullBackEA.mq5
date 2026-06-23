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
#property script_show_inputs
#include <Canvas/Canvas.mqh>
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
double running_profit = 0;
double cumulative_profit_array[];

double peak_equity = 0;
double peak_dd = 0;


double min_profit = 0;
double max_profit = 0;
bool dashboard_visible = true;

int W = 650;
int H = 300;

CCanvas canvas;
string CANVAS_NAME = "DASH_CANVAS";
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int handleMA;
int handleATR;
double bufferMA[];
double bufferATR[];
MqlTick tick;
CTrade trade;
CPositionInfo position;

bool enableEA=true;
double newPercentLot;
double peak_dd_percent=0.0;

double riskincrement=0;
double profitpercenttarget=0;
double losspercentlimit=0;
double maxdrawdown=0;
double startCapital=0;
double finishProfit=0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    
   newPercentLot=InpLotsize;
   riskincrement=0;
   profitpercenttarget=1000;
   losspercentlimit=-100;
   maxdrawdown=21;
   startCapital=100;
   finishProfit=10000; 
   
    canvas.CreateBitmapLabel(
      0, 0,
      "DASH",
      W,
      H,
         COLOR_FORMAT_ARGB_NORMALIZE
      );
   
    BuildHistory();

    Draw();
   
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

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'D') // press D
      {
         dashboard_visible = !dashboard_visible;

         if(dashboard_visible){
            canvas.Resize(W, H);
            canvas.Erase(ColorToARGB(clrBlack));
            Draw();
         }   
         else{
            canvas.Resize(1, 1); // effectively invisible
         }   
        Print("Toggle: ",dashboard_visible);    
      }
   }
}

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

void BuildHistory()
{
    // RESET STATE
   running_profit = 0;
   peak_equity = 0;
   peak_dd = 0;

   min_profit = 0;
   max_profit = 0;

   ArrayFree(cumulative_profit_array);
   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);

      if((int)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      
      ulong magicNo=HistoryDealGetInteger(deal,DEAL_MAGIC);
      
      if(magicNo==InpMagicnumber){
      Print("MagicNo: ",magicNo);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

      running_profit += profit;

      // update bounds (NO rescaling loop later)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;

      // store point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
      
      // 1. update peak equity
      if(running_profit > peak_equity)
         peak_equity = running_profit;
      
      // 2. compute drawdown
       double current_dd = peak_equity - running_profit;
      
      // 3. track worst drawdown
      if(current_dd > peak_dd)
         peak_dd = current_dd;  
       }  
   }
}


void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
     
    
    //graph code
    // 1. Only deal events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong mydeal = trans.deal;
   if(mydeal == 0)
      return;

   // 2. Load history cache
   HistorySelect(TimeCurrent() - (86400 * 30), TimeCurrent());

   // FIX: You MUST select the deal first before calling HistoryDealGetInteger!
   if(!HistoryDealSelect(mydeal))
      return;

   // 3. Only closing deals (Handles complete OUT and partial INOUT closing reversals)
   long entryType = HistoryDealGetInteger(mydeal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT)
      return;

   // 4. Extract Magic Number with Cascading Backups
   long magicNo = HistoryDealGetInteger(mydeal, DEAL_MAGIC);
   
   // Fallback A: Trace the history of the specific position lifecycle to find the opening deal
   if(magicNo == 0 && trans.position > 0)
   {
      if(HistorySelectByPosition(trans.position))
      {
         int totalDeals = HistoryDealsTotal();
         for(int i = 0; i < totalDeals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               magicNo = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               break;
            }
         }
      }
   }
   
   // Fallback B: Look directly at the order ticket that executed this closure
   if(magicNo == 0)
   {
      ulong closeOrderTicket = (ulong)HistoryDealGetInteger(mydeal, DEAL_ORDER);
      if(HistoryOrderSelect(closeOrderTicket))
      {
         magicNo = HistoryOrderGetInteger(closeOrderTicket, ORDER_MAGIC);
      }
   }

   // Fallback C: Scan history for the very first order setup using Position ID
   if(magicNo == 0 && trans.position > 0)
   {
      ulong positionID = trans.position;
      if(HistorySelectByPosition(positionID))
      {
         int totalOrders = HistoryOrdersTotal();
         for(int i = 0; i < totalOrders; i++)
         {
            ulong orderTicket = HistoryOrderGetTicket(i);
            if(HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID) == (long)positionID)
            {
               magicNo = HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);
               if(magicNo != 0) break;
            }
         }
      }
   }
   
   // 5. Execute calculations if the recovered Magic matches your EA input
   Print("Hello Processed Magic: ", magicNo);
   
   if(magicNo == InpMagicnumber)
   {
      Print("ontrade MagicNo: ", magicNo);
      double myprofit = HistoryDealGetDouble(mydeal, DEAL_PROFIT);
      Print("ontrade Profit: ", myprofit);

      // update running state
      running_profit += myprofit;
   
      // update bounds (NO rescan loop)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;
   
      // append new point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   
      // 1. update peak equity
      if(running_profit > peak_equity){
      
         peak_equity = running_profit;
         
         newPercentLot=newPercentLot+riskincrement;
         Print("######## Risk increased automatically by ######",newPercentLot);
        
         }
         
      
      // 2. compute drawdown
      double current_dd = peak_equity - running_profit;
      
      
      // 3. track worst drawdown
      if(current_dd > peak_dd){
         peak_dd = current_dd;
         
         
         
         newPercentLot=newPercentLot-riskincrement;
         
         Print("######## Risk Decreased automatically by ######",newPercentLot);
          
         }
      //if(peak_equity>0)
      {   
         peak_dd_percent = (peak_dd/(startCapital+peak_equity))*100;
      } 
      Print("peak_equity: ",peak_equity," peak_dd: ",peak_dd," ratio of peakdd: ",(peak_dd/(startCapital+peak_equity)));
       
      if(peak_dd_percent >maxdrawdown)
        {
          enableEA=false;
          
          Print("========EA draw Limit hit========");
        }    
        
      Draw();              // build chart
      ChartRedraw();       // force refresh
         
      Print("Draw again ", running_profit, " profit: ", myprofit);
   }
    //graph code 
   
  }
  
  
  
  void Draw()
{
   canvas.Erase(ColorToARGB(clrBlack));

   int n = ArraySize(cumulative_profit_array);

   double chart_range  = max_profit - min_profit;
   if(chart_range  == 0) chart_range  = 1;

   if(n >= 2)
   {
      int prev_x = 0;
      int prev_y = 0;

      for(int i = 0; i < n; i++)
      {
         int x = (int)((double)i / (n - 1) * W);

         double value = cumulative_profit_array[i];

         int y = H - (int)((value - min_profit) / chart_range  * (H-20))-20;
         
         if(i > 0)
            canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrWhite));
            

         prev_x = x;
         prev_y = y;
      }
   }

   // ✅ ALWAYS draw text (even if n < 2)
   canvas.FontSet("Consolas", 14);

   string text =
      _Symbol+" Click 'D' to hide/show | PnL: " +
      DoubleToString(startCapital+running_profit, 2)+" peak_equity: "+DoubleToString(startCapital+peak_equity,2)+" peak_dd: -"+DoubleToString(peak_dd,2);
   Print("peak_equity: ",peak_dd);
   canvas.TextOut(30, 15, text, ColorToARGB(clrWhite));
   string alloweddd="Max Allowed DD: -"+DoubleToString(maxdrawdown,1)+"% currentDD %:- "+DoubleToString(peak_dd_percent,2)+" Risk %:"+DoubleToString(newPercentLot,2);
   canvas.TextOut(30, 30, alloweddd, ColorToARGB(clrWhite));
   string accountName="Account Name: "+AccountInfoString(ACCOUNT_NAME);
   canvas.TextOut(30, 45, accountName, ColorToARGB(clrWhite));
   
   int ddline = H - (int)((peak_equity-min_profit) / chart_range * (H - 20)) - 20;
   Print("peak_equity ",peak_equity," min_profit: ",min_profit," max_profit: ",max_profit);
   //canvas.Line(0, ddline, W, ddline, ColorToARGB(clrBeige));
   canvas.Update(true);
}