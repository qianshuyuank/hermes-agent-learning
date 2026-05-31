import smtplib
from email.message import EmailMessage
import datetime

with open('/home/bitq/github/hermes-agent-learning/reports/daily_briefing_latest.md', 'r') as f:
    content = f.read()

msg = EmailMessage()
msg.set_content(content)
msg['Subject'] = f"📅 秘书每日情报汇总 {datetime.date.today().isoformat()}"
msg['From'] = 'anhthov194@gmail.com'
msg['To'] = 'anhthov194@gmail.com'

try:
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
        server.login('anhthov194@gmail.com', 'dlld kbuz fhhu wmev')
        server.send_message(msg)
    print("Successfully sent email via smtplib (SSL)")
except Exception as e:
    print(f"Failed to send email: {e}")
