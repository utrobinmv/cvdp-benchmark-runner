# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Custom model factory for any OpenAI-compatible API endpoint.

Reads configuration from environment variables:
  BASE_URL   - OpenAI-compatible API base URL (e.g. http://host:port/v1)
  API_KEY    - API key for authentication
  MODEL      - Model name/identifier to pass to the API
"""

import openai
import os
import logging
from typing import Optional, Any
from src.config_manager import config
from src.model_helpers import ModelHelpers
from src.llm_lib.model_factory import ModelFactory

logging.basicConfig(level=logging.INFO)


class CustomOpenAI_Instance:
    """Model instance that connects to any OpenAI-compatible API endpoint."""

    def __init__(
        self, context: str = "You are a helpful assistant.", key=None, model=None
    ):
        if model is None:
            model = os.getenv("MODEL", config.get("DEFAULT_MODEL", "gpt-4o-mini"))

        self.context = context
        self.model = model
        self.debug = False

        api_key = key or os.getenv("API_KEY")
        base_url = os.getenv("BASE_URL")

        if api_key is None:
            raise ValueError(
                "Unable to create CustomOpenAI Model: No API key provided. "
                "Set API_KEY environment variable."
            )

        if base_url is None:
            raise ValueError(
                "Unable to create CustomOpenAI Model: No BASE_URL provided. "
                "Set BASE_URL environment variable."
            )

        self.chat = openai.OpenAI(api_key=api_key, base_url=base_url)
        logging.info(
            f"Created CustomOpenAI Model. "
            f"Using model: {self.model}, base_url: {base_url}"
        )

        self.set_debug(False)

    def key(self, key: str) -> None:
        base_url = os.getenv("BASE_URL")
        self.chat = openai.OpenAI(api_key=key, base_url=base_url)

    @property
    def requires_evaluation(self) -> bool:
        return True

    def set_debug(self, debug: bool = True) -> None:
        self.debug = debug
        logging.info(f"Debug mode {'enabled' if debug else 'disabled'}")

    def prompt(
        self,
        prompt: str,
        schema: Optional[str] = None,
        prompt_log: str = "",
        files: Optional[list] = None,
        timeout: int = 60,
        category: Optional[Any] = None,
    ) -> str:
        """Send a prompt to the model and get a response."""
        if self.chat is None:
            raise ValueError("Unable to detect Chat Model")

        helper = ModelHelpers()
        system_prompt = helper.create_system_prompt(self.context, schema, category)

        if timeout == 60:
            timeout = config.get("MODEL_TIMEOUT", 60)

        expected_single_file = files and len(files) == 1 and schema is None

        if self.debug:
            logging.debug(f"Requesting prompt using the model: {self.model}")
            logging.debug(f"System prompt: {system_prompt}")
            logging.debug(f"User prompt: {prompt}")
            if files:
                logging.debug(f"Expected files: {files}")
            logging.debug(
                f"Request parameters: model={self.model}, timeout={timeout}"
            )

        if prompt_log:
            try:
                os.makedirs(os.path.dirname(prompt_log), exist_ok=True)
                temp_log = f"{prompt_log}.tmp"
                with open(temp_log, "w+") as f:
                    f.write(
                        system_prompt
                        + "\n\n----------------------------------------\n"
                        + prompt
                    )
                os.replace(temp_log, prompt_log)
            except Exception as e:
                logging.error(f"Failed to write prompt log to {prompt_log}: {str(e)}")
                raise

        try:
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": prompt.strip()})

            response = self.chat.chat.completions.create(
                model=self.model, messages=messages, timeout=timeout
            )

            if self.debug:
                logging.debug(f"Response received:\n{response}")

            for choice in response.choices:
                message = choice.message
                if self.debug:
                    logging.debug(f"  - Message: {message.content}")

                content = message.content.strip()

                return helper.parse_model_response(
                    content, files, expected_single_file
                )

        except Exception as e:
            raise ValueError(
                f"Unable to get response from CustomOpenAI model: {str(e)}"
            )


class CustomModelFactory(ModelFactory):
    """Factory that routes all model requests to a custom OpenAI-compatible endpoint."""

    def __init__(self):
        super().__init__()
        logging.info("CustomModelFactory initialized for OpenAI-compatible endpoint")

    def create_model(
        self,
        model_name: str,
        context: Any = None,
        key: Optional[str] = None,
        **kwargs,
    ) -> Any:
        return CustomOpenAI_Instance(context=context, key=key, model=model_name)
