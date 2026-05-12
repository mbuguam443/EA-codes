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

double min_profit = 0;
double max_profit = 0;
bool dashboard_visible = true;

int W = 600;
int H = 300;

CCanvas canvas;
string CANVAS_NAME = "DASH_CANVAS";




int OnInit()
  {
    totalbarM1=iBars(_Symbol,PERIOD_M1);
   trade.Buy(0.01);
   
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
        trade.PositionClose(_Symbol);
        //Print("Trade Close Automatically.");
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

   // 2. Load history
   HistorySelect(0, TimeCurrent());

   // 3. Only closing deals
   if((int)HistoryDealGetInteger(mydeal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;

   // 4. Get profit
   double myprofit = HistoryDealGetDouble(mydeal, DEAL_PROFIT);

    Print("Profit: ", myprofit);


      // update running state
      running_profit += myprofit;
   
      // update bounds (NO rescan loop)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;
   
      // append new point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   
        
         Draw();              // build chart
         ChartRedraw();       // force refresh
         
       
      Print("Draw again ",running_profit," profit: ",myprofit);
   
   
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
   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);

      if((int)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

      running_profit += profit;

      // update bounds (NO rescaling loop later)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;

      // store point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   }
}

void Draw()
{
   canvas.Erase(ColorToARGB(clrBlack));

   int n = ArraySize(cumulative_profit_array);

   double range = max_profit - min_profit;
   if(range == 0) range = 1;

   if(n >= 2)
   {
      int prev_x = 0;
      int prev_y = 0;

      for(int i = 0; i < n; i++)
      {
         int x = (int)((double)i / (n - 1) * W);

         double value = cumulative_profit_array[i];

         int y = H - (int)((value - min_profit) / range * H);

         if(i > 0)
            canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrLime));

         prev_x = x;
         prev_y = y;
      }
   }

   // ✅ ALWAYS draw text (even if n < 2)
   canvas.FontSet("Consolas", 15);

   string text =
      "Click 'D' to hide/show | PnL: " +
      DoubleToString(running_profit, 2);

   canvas.TextOut(150, 15, text, ColorToARGB(clrWhite));

   canvas.Update(true);
}