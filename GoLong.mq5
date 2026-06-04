//+------------------------------------------------------------------+
//| Daily Buy EA - Simple Version                                    |
//| Opens one BUY when the first bar reaches/passes 01:55            |
//| Closes all BUY positions when the first bar reaches/passes 23:00 |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs
input double LotSize     = 0.01;
input int    MagicNumber = 12345;
input double AllowedDD=21;

bool longopen=false;

//graph code
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
//graph code

//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   if(trade.Buy(LotSize, _Symbol,0,0,0,"Go long"))
   {
      Print("BUY opened successfully at ",
            TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
            longopen=true;
   }
   else
   {
      Print("BUY failed. Retcode = ",
            trade.ResultRetcode(),
            " - ",
            trade.ResultRetcodeDescription());
            longopen=false;
   }
}


void OnDeinit(const int32_t reason)
  {
      canvas.Destroy();
      ObjectsDeleteAll(0, "DASH");
      ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Close all BUY positions opened by this EA                        |
//+------------------------------------------------------------------+
void CloseBuyPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      // Only close BUY positions opened by this EA
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(trade.PositionClose(ticket))
         {
            Print("Closed BUY ticket ", ticket,
                  " at ",
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
                  longopen=false;
         }
         else
         {
            Print("Failed to close ticket ", ticket,
                  ". Retcode = ",
                  trade.ResultRetcode(),
                  " - ",
                  trade.ResultRetcodeDescription());
                  longopen=true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   Print("Daily Buy EA initialized.");
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
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
  
  
      
  
  
      datetime dayStart=TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(dayStart, dt);
   
      // Open time = 01:55
      dt.hour = 1;
      dt.min  = 55;
      dt.sec  = 0;
      datetime openTime = StructToTime(dt);
   
      // Close time = 23:00 (you confirmed this detects correctly)
      dt.hour = 23;
      dt.min  = 0;
      dt.sec  = 0;
      datetime closeTime = StructToTime(dt);
   
      // Current bar open time
      datetime barTime = TimeCurrent();
   
      //---------------------------------------------------------------
      // OPEN BUY ONCE PER DAY
      //---------------------------------------------------------------
      if(!longopen && barTime >= openTime)
      {
        Print("==============Opening Long Trade=======================",barTime);
         //lastOpenDay = dayStart;
         OpenBuy();
         
      }
   
      //---------------------------------------------------------------
      // CLOSE BUY ONCE PER DAY
      //---------------------------------------------------------------
      if(longopen && barTime >= closeTime)
      {
         Print("=============Closing the long trade============================",barTime);
         //lastCloseDay = dayStart;
         CloseBuyPositions();
         
      }
      
}
//+------------------------------------------------------------------+

double CalculateLotSize(int Percent,double slDistance)
{
   double tickSize= SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue= SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ticklotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double ticklotMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double ticklotMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   
   Print("tickSize: ",tickSize," tickValue: ",tickValue," tickLotStep: ",ticklotStep," tickMin: ",ticklotMin," tickmax: ",ticklotMax);
   
   if(tickSize==0 || tickValue==0 || ticklotStep==0 )
     {
       return 0;
     }
     
   double riskMoney= AccountInfoDouble(ACCOUNT_EQUITY)*Percent/100;
   
   double moneyPerSmallestLotsize= (slDistance/tickSize)*tickValue*ticklotStep;
   Print("slDistance: ",slDistance,"riskMoney: ",riskMoney," smallest you can riskMoney: ",moneyPerSmallestLotsize);
   if(moneyPerSmallestLotsize==0)
     {
      return 0;
     }
   double lotsFactor= (riskMoney/moneyPerSmallestLotsize);  
   double lots= MathFloor(riskMoney/moneyPerSmallestLotsize)* ticklotStep;
   if(moneyPerSmallestLotsize >riskMoney)
     {
      lots=ticklotMin;
     }
   if(lots > ticklotMax)
     {
      lots=ticklotMax;
     }  
   Print("The Lot Factor between the two is: ",lotsFactor);
   Print("The Lots size to be used: ",lots);
   return lots; 
    
}

//graph code 
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
   
   if(magicNo == MagicNumber)
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
      
      if(magicNo==MagicNumber){
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
//graph code 