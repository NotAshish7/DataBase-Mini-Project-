USE GamblingWebsite;

-- 1. Calculate the total revenue generated from each game category
SELECT gc.CategoryName, SUM(b.BetAmount) AS TotalBets, 
       SUM(CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
                WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
                ELSE 0 END) AS Revenue
FROM Bets b
JOIN Games g ON b.GameID = g.GameID
JOIN GameCategories gc ON g.CategoryID = gc.CategoryID
WHERE b.BetStatus IN ('Won', 'Lost')
GROUP BY gc.CategoryName
ORDER BY Revenue DESC;

-- 2. Get the most active games based on bet count in the last 30 days
SELECT g.GameName, COUNT(b.BetID) AS BetCount, SUM(b.BetAmount) AS TotalWagered
FROM Games g
JOIN Bets b ON g.GameID = b.GameID
WHERE b.BetTime >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 30 DAY)
GROUP BY g.GameName
ORDER BY BetCount DESC
LIMIT 5;

-- 3. Get all open support tickets with high priority and their latest message
SELECT st.TicketID, u.Username, st.Subject, st.Priority, st.CreatedDate,
       (SELECT tm.MessageText 
        FROM TicketMessages tm 
        WHERE tm.TicketID = st.TicketID 
        ORDER BY tm.SentDate DESC 
        LIMIT 1) AS LatestMessage
FROM SupportTickets st
JOIN Users u ON st.UserID = u.UserID
WHERE st.Status = 'Open' AND st.Priority IN ('High', 'Urgent')
ORDER BY st.Priority, st.CreatedDate;

-- 4. Find payment methods with the highest transaction volumes
SELECT pm.MethodName, 
       COUNT(t.TransactionID) AS TransactionCount,
       SUM(t.Amount) AS TotalVolume,
       SUM(CASE WHEN t.TransactionType = 'Deposit' THEN t.Amount ELSE 0 END) AS TotalDeposits,
       SUM(CASE WHEN t.TransactionType = 'Withdrawal' THEN t.Amount ELSE 0 END) AS TotalWithdrawals
FROM PaymentMethods pm
JOIN Transactions t ON pm.PaymentMethodID = t.PaymentMethodID
WHERE t.Status = 'Completed'
GROUP BY pm.MethodName
ORDER BY TotalVolume DESC;

-- 5. Get a summary of admin activities by role
SELECT a.Role, COUNT(DISTINCT a.AdminID) AS AdminCount,
       COUNT(tm.MessageID) AS SupportMessages
FROM Admins a
LEFT JOIN TicketMessages tm ON a.AdminID = tm.SenderID AND tm.SenderType = 'Admin'
GROUP BY a.Role
ORDER BY SupportMessages DESC;

-- 6. Find games with the highest house edge and their performance
SELECT g.GameName, g.HouseEdge, 
       COUNT(b.BetID) AS TotalBets,
       SUM(b.BetAmount) AS TotalWagered,
       SUM(CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
                WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
                ELSE 0 END) AS ActualProfit,
       (SUM(CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
                 WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
                 ELSE 0 END) / SUM(b.BetAmount)) * 100 AS ActualMargin
FROM Games g
LEFT JOIN Bets b ON g.GameID = b.GameID
WHERE b.BetStatus IN ('Won', 'Lost')
GROUP BY g.GameName, g.HouseEdge
ORDER BY g.HouseEdge DESC;

-- 7. Find users who have verification issues (phone verified but ID not verified)
SELECT u.UserID, u.Username, u.Email, u.Phone, u.CountryCode,
       v.PhoneVerified, v.OTPStatus, v.IDType, v.IDVerified
FROM Users u
JOIN Verification v ON u.UserID = v.UserID
WHERE v.PhoneVerified = 1 AND v.IDVerified = 0
ORDER BY u.RegistrationDate;

-- 8. Get a comprehensive user activity report
SELECT u.Username, u.CountryCode, 
       a.Balance, a.TotalWagered, a.TotalWon, a.TotalLost,
       COUNT(DISTINCT b.BetID) AS BetCount,
       COUNT(DISTINCT t.TransactionID) AS TransactionCount,
       COUNT(DISTINCT st.TicketID) AS TicketCount,
       MAX(b.BetTime) AS LastBetDate,
       MAX(t.TransactionDate) AS LastTransactionDate,
       u.LastLoginDate
FROM Users u
LEFT JOIN AccountSummary a ON u.UserID = a.UserID
LEFT JOIN Bets b ON u.UserID = b.UserID
LEFT JOIN Transactions t ON u.UserID = t.UserID
LEFT JOIN SupportTickets st ON u.UserID = st.UserID
GROUP BY u.Username, u.CountryCode, a.Balance, a.TotalWagered, a.TotalWon, a.TotalLost, u.LastLoginDate
ORDER BY a.TotalWagered DESC;

-- 9. Identify country-specific game preferences
SELECT u.CountryCode, gc.CategoryName, COUNT(b.BetID) AS BetCount,
       ROUND((COUNT(b.BetID) * 100.0 / 
             (SELECT COUNT(*) FROM Bets b2 
              JOIN Users u2 ON b2.UserID = u2.UserID 
              WHERE u2.CountryCode = u.CountryCode)), 2) AS PercentageOfCountryBets
FROM Users u
JOIN Bets b ON u.UserID = b.UserID
JOIN Games g ON b.GameID = g.GameID
JOIN GameCategories gc ON g.CategoryID = gc.CategoryID
GROUP BY u.CountryCode, gc.CategoryName
HAVING COUNT(b.BetID) > 0
ORDER BY u.CountryCode, BetCount DESC;

-- 10. Analyze the relationship between game house edge and actual profit margin
SELECT 
    g.HouseEdge AS TheoreticalEdge,
    ROUND(AVG((CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
                    WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
                    ELSE 0 END) / b.BetAmount * 100), 2) AS ActualMargin,
    ROUND(AVG((CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
                    WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
                    ELSE 0 END) / b.BetAmount * 100) - g.HouseEdge, 2) AS MarginDifference,
    COUNT(DISTINCT g.GameID) AS GameCount,
    SUM(b.BetAmount) AS TotalWagered
FROM Games g
JOIN Bets b ON g.GameID = b.GameID
WHERE b.BetStatus IN ('Won', 'Lost')
GROUP BY g.HouseEdge
ORDER BY g.HouseEdge;

-- 11. Calculate the average response and resolution time for support tickets by category
SELECT 
    st.Category,
    COUNT(st.TicketID) AS TotalTickets,
    AVG(TIMESTAMPDIFF(MINUTE, st.CreatedDate, 
        (SELECT MIN(tm.SentDate) 
         FROM TicketMessages tm 
         WHERE tm.TicketID = st.TicketID AND tm.SenderType IN ('Support', 'Admin')))) AS AvgFirstResponseMinutes,
    AVG(CASE WHEN st.Status = 'Closed' 
             THEN TIMESTAMPDIFF(HOUR, st.CreatedDate, st.ClosedDate) 
             ELSE NULL END) AS AvgResolutionHours,
    COUNT(CASE WHEN st.Status = 'Closed' THEN 1 ELSE NULL END) AS ClosedTickets,
    (COUNT(CASE WHEN st.Status = 'Closed' THEN 1 ELSE NULL END) * 100.0 / COUNT(st.TicketID)) AS ClosureRate
FROM SupportTickets st
GROUP BY st.Category
HAVING COUNT(st.TicketID) > 0
ORDER BY AvgFirstResponseMinutes;

-- 12. Find the most profitable time periods for the platform (hourly analysis)
SELECT 
    HOUR(b.BetTime) AS HourOfDay,
    COUNT(b.BetID) AS TotalBets,
    SUM(b.BetAmount) AS TotalWagered,
    SUM(CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
             WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
             ELSE 0 END) AS Revenue,
    (SUM(CASE WHEN b.BetStatus = 'Lost' THEN b.BetAmount 
              WHEN b.BetStatus = 'Won' THEN b.BetAmount - b.ActualPayout
              ELSE 0 END) / SUM(b.BetAmount) * 100) AS ProfitMargin,
    COUNT(DISTINCT u.UserID) AS UniqueUsers
FROM Bets b
JOIN Users u ON b.UserID = u.UserID
WHERE b.BetStatus IN ('Won', 'Lost')
GROUP BY HOUR(b.BetTime)
ORDER BY Revenue DESC;

-- 13. Analyze cross-selling opportunities (users who play multiple game categories)
WITH UserCategoryCounts AS (
    SELECT 
        u.UserID,
        u.Username,
        COUNT(DISTINCT g.CategoryID) AS CategoryCount,
        GROUP_CONCAT(DISTINCT gc.CategoryName ORDER BY gc.CategoryName SEPARATOR ', ') AS Categories
    FROM Users u
    JOIN Bets b ON u.UserID = b.UserID
    JOIN Games g ON b.GameID = g.GameID
    JOIN GameCategories gc ON g.CategoryID = gc.CategoryID
    GROUP BY u.UserID, u.Username
)

SELECT 
    CategoryCount,
    COUNT(UserID) AS UserCount,
    (COUNT(UserID) * 100.0 / (SELECT COUNT(DISTINCT UserID) FROM Bets)) AS PercentageOfUsers,
    Categories
FROM UserCategoryCounts
GROUP BY CategoryCount, Categories
ORDER BY CategoryCount DESC;
