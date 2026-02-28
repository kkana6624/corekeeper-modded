import os
import discord
from discord.ext import commands
import logging
from dotenv import load_dotenv

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('corekeeper_bot')

# Load Environment
load_dotenv()
TOKEN = os.getenv('DISCORD_BOT_TOKEN')

if not TOKEN:
    logger.error("DISCORD_BOT_TOKEN is not set!")
    exit(1)

# Bot Setup
intents = discord.Intents.default()
intents.message_content = True # Required for some commands

bot = commands.Bot(command_prefix='!', intents=intents)

@bot.event
async def on_ready():
    logger.info(f'Logged in as {bot.user} (ID: {bot.user.id})')
    logger.info('------')
    
    logger.info('------')
    
    # Load Cogs
    try:
        # await bot.load_extension('cogs.status')
        # logger.info('Loaded extension: cogs.status')
        await bot.load_extension('cogs.commands')
        logger.info('Loaded extension: cogs.commands')
        
        # Sync Slash Commands
        synced = await bot.tree.sync()
        logger.info(f'Synced {len(synced)} command(s)')
    except Exception as e:
        logger.error(f'Failed to load extension cogs.status: {e}')

@bot.command()
async def ping(ctx):
    await ctx.send('Pong! 🏓')

if __name__ == "__main__":
    bot.run(TOKEN)
