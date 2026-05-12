//+------------------------------------------------------------------+
//|                                                  graphdrawer.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Canvas/Canvas.mqh>

CCanvas canvas;

input long InpMagic=49939443;


double running_profit = 0;
double cumulative_profit_array[];

int OnInit()
  {
   buildhistory();
   DrawDash();
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   // destroy canvas
   canvas.Destroy();

   // remove chart object
   ObjectDelete(0, "canvas");

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

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
     if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
     DrawDash(); 
  }

void DrawDash()
{
   // -----------------------------
   // Canvas 300x300
   // -----------------------------
   
   
   
   
   
   int width  = 600;
   int height = 300;

   canvas.CreateBitmapLabel(
      0, 0,
      "canvas",
      width,
      height,
      COLOR_FORMAT_ARGB_NORMALIZE
   );

   canvas.Erase(ColorToARGB(clrBlack));

   // -----------------------------
   // 10,000 DATA POINTS
   // -----------------------------
   
   //------end here---
   
   
   
   int total = ArraySize(cumulative_profit_array);

   // -----------------------------
   // Find min/max
   // -----------------------------
   double minVal = cumulative_profit_array[0];
   double maxVal = cumulative_profit_array[0];

   for(int i = 0; i < total; i++)
   {
      if(cumulative_profit_array[i] < minVal) minVal = cumulative_profit_array[i];
      if(cumulative_profit_array[i] > maxVal) maxVal = cumulative_profit_array[i];
   }

   double range = maxVal - minVal;
   if(range == 0) range = 1;

   // -----------------------------
   // Draw scaled graph
   // -----------------------------
   int prevX = 0;
   int prevY = 0;
   bool first = true;

   for(int i = 0; i < total; i++)
   {
      // X scaling (compress 10k → 300)
      int x = (int)((double)i / (total - 1) * width);

      // Y scaling (normalize)
      double norm = (cumulative_profit_array[i] - minVal) / range;

      int y = (int)((1.0 - norm) * height)-5;

      // draw line
      if(!first)
      {
         canvas.Line(prevX, prevY, x, y, ColorToARGB(clrLime));
         //canvas.Circle(prevX, prevY,3,ColorToARGB(clrWhite));
      }

      prevX = x;
      prevY = y;
      first = false;
   }
   
   

   string txt = "PnL: " + DoubleToString(running_profit,2);
   
   // simple safe positioning
   int x = 60;
   int y = 10;
   
   canvas.FontSet("Arial", 14);
   // draw text
   canvas.TextOut(x,y,txt,ColorToARGB(clrWhite));

   canvas.Update(true);

   Print("Number of trades: ",ArraySize(cumulative_profit_array));
}


void buildhistory()
{
   datetime from = 0;
   //datetime from = D'2026.04.09 00:00';
   datetime to   = TimeCurrent();

   if(!HistorySelect(from, to))
   {
      Print("Failed to select history");
      return;
   }

   int newtotal = HistoryDealsTotal();

   ArrayResize(cumulative_profit_array, 0);

   

   Print("===== CUMULATIVE PROFIT TRACKING =====");

   for(int i = 0; i < newtotal; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);

      int dealType = (int)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

      // only closed trades
      if(dealType == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         ulong magicno=HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
         //if(magicno==InpMagic)
           {
               running_profit += profit;

               // store cumulative value
               int size = ArraySize(cumulative_profit_array);
               ArrayResize(cumulative_profit_array, size + 1);
               cumulative_profit_array[size] = running_profit;
      
               Print("Trade Profit: ", profit,
                     " | Cumulative: ", running_profit);
           }
         
      }
   }
}