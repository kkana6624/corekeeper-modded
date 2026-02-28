import discord
from discord.ext import commands, tasks
import os
import logging
import asyncio
from datetime import datetime

class Status(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.logger = logging.getLogger('corekeeper_bot')
        self.channel_id = int(os.getenv('DISCORD_STATUS_CHANNEL_ID', 0))
        self.message = None
        
        # Paths (mounted in Docker)
        self.game_id_path = "/home/steam/core-keeper-data/GameID.txt"
        
        # Start the loop
        self.status_task.start()

    def cog_unload(self):
        self.status_task.cancel()

    @tasks.loop(seconds=60)
    async def status_task(self):
        await self.bot.wait_until_ready()
        
        if self.channel_id == 0:
            self.logger.warning("DISCORD_STATUS_CHANNEL_ID is not set.")
            return

        try:
            channel = self.bot.get_channel(self.channel_id)
            if not channel:
                # Might be None if cache not ready or ID invalid
                try:
                    channel = await self.bot.fetch_channel(self.channel_id)
                except Exception as e:
                    self.logger.error(f"Failed to fetch channel: {e}")
                    return

            # --- Check Server Status ---
            game_id = "Unknown"
            status_color = 0x99AAB5 # Grey (Unknown)
            status_text = "⚪ Connecting..."
            
            if os.path.exists(self.game_id_path):
                try:
                    with open(self.game_id_path, 'r') as f:
                        content = f.read().strip()
                        if content:
                            game_id = content
                            status_color = 0x57F287 # Green
                            status_text = "🟢 **Online**"
                        else:
                            status_text = "🟡 **Starting...**"
                            status_color = 0xFEE75C # Yellow
                except Exception as e:
                    self.logger.error(f"Error reading GameID: {e}")
            else:
                status_color = 0xED4245 # Red
                status_text = "🔴 **Offline**"
                game_id = "Server Stopped"

            # --- Configure Embed ---
            embed = discord.Embed(title="Server Status", color=status_color)
            embed.set_thumbnail(url="https://img.icons8.com/color/96/server.png") # Placeholder icon
            embed.add_field(name="Status", value=status_text, inline=True)
            
            if game_id and game_id != "Server Stopped" and game_id != "Unknown":
                embed.add_field(name="Game ID", value=f"```\n{game_id}\n```", inline=False)
            
            embed.set_footer(text=f"Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

            # --- Update or Send Message ---
            # Ideally we keep one message. For simplicity in this v1, 
            # we search for the LAST message sent by the bot in this channel.
            
            if not self.message:
                async for msg in channel.history(limit=10):
                    if msg.author == self.bot.user:
                        self.message = msg
                        break

            if self.message:
                await self.message.edit(embed=embed)
            else:
                self.message = await channel.send(embed=embed)

        except Exception as e:
            self.logger.error(f"Error in status task: {e}")

async def setup(bot):
    await bot.add_cog(Status(bot))
