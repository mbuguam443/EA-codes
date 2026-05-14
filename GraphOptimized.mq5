//+------------------------------------------------------------------+
//|                                               GraphOptimized.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include<Trade/Trade.mqh>
CTrade trade;
int totalbarM1=0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#property script_show_inputs
#include <Canvas/Canvas.mqh>

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
input ulong InpMagic=45459;
input double AllowedDD=21;



int OnInit()
  {
    totalbarM1=iBars(_Symbol,PERIOD_M1);
    trade.SetExpertMagicNumber(InpMagic);
    trade.Buy(0.01,NULL,0,0,0,"grap optimized");
   
   canvas.CreateBitmapLabel(
      0, 0,
      "DASH",
      W,
      H,
      COLOR_FORMAT_ARGB_NORMALIZE
   );
   
  
   BuildHistory();

   Draw();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
     canvas.Destroy();
      ObjectsDeleteAll(0, "DASH");
      ChartRedraw();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
       
       
//---
    int bars=iBars(_Symbol,PERIOD_M1);
    if(totalbarM1!=bars)
      {
       totalbarM1=bars;
       Print("New bar detected");
       if(peak_dd > AllowedDD)return;
        trade.PositionClose(_Symbol);
        Print("Trade Close Automatically. after one minute");
       
      }
      
  }
//+------------------------------------------------------------------+

void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
{
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
   
   if(magicNo == InpMagic)
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
      if(running_profit > peak_equity)
         peak_equity = running_profit;
      
      // 2. compute drawdown
      double current_dd = peak_equity - running_profit;
      
      // 3. track worst drawdown
      if(current_dd > peak_dd)
         peak_dd = current_dd;
        
      Draw();              // build chart
      ChartRedraw();       // force refresh
         
      Print("Draw again ", running_profit, " profit: ", myprofit);
   }
}

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
      
      if(magicNo==InpMagic){
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
            canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrBlue));

         prev_x = x;
         prev_y = y;
      }
   }

   // ✅ ALWAYS draw text (even if n < 2)
   canvas.FontSet("Consolas", 14);

   string text =
      "Click 'D' to hide/show | PnL: " +
      DoubleToString(running_profit, 2)+" peak_equity: "+DoubleToString(peak_equity,2)+" peak_dd: -"+DoubleToString(peak_dd,2);
   Print("peak_equity: ",peak_dd);
   canvas.TextOut(30, 15, text, ColorToARGB(clrWhite));
   string alloweddd="Max Allowed DD: -"+DoubleToString(AllowedDD,2);
   canvas.TextOut(30, 30, alloweddd, ColorToARGB(clrWhite));

   canvas.Update(true);
}