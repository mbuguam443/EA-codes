//+------------------------------------------------------------------+
//|                                               GraphOptimized.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
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
   
  }
//+------------------------------------------------------------------+

void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong deal = trans.deal;

   HistorySelect(0, TimeCurrent());

   if((int)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
   {
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

      // update running state
      running_profit += profit;
   
      // update bounds (NO rescan loop)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;
   
      // append new point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   
      Draw();
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

   if(n < 2)
      return;

   double range = max_profit - min_profit;
   if(range == 0) range = 1;

   int prev_x = 0;
   int prev_y = 0;

   for(int i = 0; i < n; i++)
   {
      int x = (int)((double)i / (n - 1) * W);

      double value = cumulative_profit_array[i];

      int y = H - (int)((value - min_profit) / range * H);

      // draw line
      if(i > 0)
         canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrLime));

      // draw point
      //canvas.FillCircle(x, y, 2, ColorToARGB(clrWhite));

      prev_x = x;
      prev_y = y;
   }

   // label
   canvas.FontSet("Consolas", 15);

   canvas.TextOut(
      150,
      15,
      "Click 'D' to hide\show PnL: " + DoubleToString(running_profit, 2),
      ColorToARGB(clrWhite)
   );

   canvas.Update();
}