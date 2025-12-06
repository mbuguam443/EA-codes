//+------------------------------------------------------------------+
//|                                                     testdeal.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade/Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
     trade.SetExpertMagicNumber(Magic);
     trade.Buy(0.01);
     ulong ticket = CreateBuyLimit(0.10, 500, 12345);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    //ClosePendingOrdersByMagic(Magic);
  }
//+------------------------------------------------------------------+
int Magic = 123456;

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // When a new deal is created
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong posTicket = trans.position;
        
        // Load the position to check magic number
        if(PositionSelectByTicket(posTicket))
        {
            int posMagic = (int)PositionGetInteger(POSITION_MAGIC);

            // Only react to THIS EA's position
            if(posMagic == Magic)
            {
                Print("My EA opened a position!");
                ClosePendingOrdersByMagic(Magic);
                // Now delete all pending orders from this EA
               // DeleteMyPendingOrders();
            }
        }
    }
}

void ClosePendingOrdersByMagic(int magicNumber)
{
   // iterate backwards so deleting doesn't break indexing
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
       ulong ticket = OrderGetTicket(i); 
      // select order by position from the pool of current (open & pending) orders
      if(OrderSelect(ticket))
      {
         
         int type = (int)OrderGetInteger(ORDER_TYPE);
         int magic = (int)OrderGetInteger(ORDER_MAGIC);

         // target pending order types only
         if(type == ORDER_TYPE_BUY_LIMIT  ||
            type == ORDER_TYPE_SELL_LIMIT ||
            type == ORDER_TYPE_BUY_STOP   ||
            type == ORDER_TYPE_SELL_STOP  ||
            type == ORDER_TYPE_BUY_STOP_LIMIT ||
            type == ORDER_TYPE_SELL_STOP_LIMIT)
         {
            if(magic == magicNumber)
            {
               Print("we are in here");
               // attempt to delete/cancel the pending order
               if(!trade.OrderDelete(ticket))
               {
                  PrintFormat("Failed to delete pending order #%I64u (magic=%d). Error=%d",
                              ticket, magic, GetLastError());
               }
               else
               {
                  PrintFormat("Deleted pending order #%I64u (magic=%d).", ticket, magic);
               }
            }
         }
      }
      else
      {
         // If OrderSelect fails, print error (helps debugging)
         PrintFormat("OrderSelect(%d) failed, Error=%d", i, GetLastError());
      }
   }
}

// Creates a Buy Limit pending order
ulong CreateBuyLimit(double lots, int distancePoints, int magicNumber)
{
    double price = NormalizeDouble(
        SymbolInfoDouble(_Symbol, SYMBOL_BID) - distancePoints * _Point,
        _Digits
    );

    double sl = price - 300 * _Point;
    double tp = price + 300 * _Point;

    if(trade.BuyLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, magicNumber))
    {
        ulong ticket = trade.ResultOrder();
        PrintFormat("Buy Limit created. Ticket=%I64u", ticket);
        return ticket;
    }
    else
    {
        PrintFormat("BuyLimit failed. Retcode=%d", trade.ResultRetcode());
        return 0;
    }
}
